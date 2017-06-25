-- Test suite for com package
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015-2017, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

library ieee;
use ieee.std_logic_1164.all;

use std.textio.all;

entity tb_com is
  generic (
    runner_cfg : string);
end entity tb_com;

architecture test_fixture of tb_com is
  signal hello_world_received, start_receiver, start_server,
    start_server2, start_server3, start_server4, start_subscribers : boolean := false;
  signal hello_subscriber_received                     : std_logic_vector(1 to 2) := "ZZ";
  signal start_limited_inbox, limited_inbox_actor_done : boolean                  := false;
  signal start_limited_inbox_subscriber                : boolean                  := false;
begin
  test_runner : process
    variable self, actor, actor2, receiver, server, publisher, subscriber : actor_t;
    variable status                                                       : com_status_t;
    variable receipt, receipt2, receipt3                                  : receipt_t;
    variable n_actors                                                     : natural;
    variable message                                                      : message_ptr_t;
    variable reply_message                                                : message_ptr_t;
    variable request_message                                              : message_ptr_t;
    variable t_start, t_stop                                              : time;
    variable ack                                                          : boolean;
  begin
    checker_init(display_format => verbose,
                 file_name      => join(output_path(runner_cfg), "error.csv"),
                 file_format    => verbose_csv);
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      reset_messenger;
      self := create("test runner");

      -- Create
      if run("Test that named actors can be created") then
        n_actors := num_of_actors;
        check(create("actor") /= null_actor_c, "Failed to create named actor");
        check_equal(num_of_actors, n_actors + 1, "Expected one extra actor");
        check(create("other actor").id /= create("another actor").id, "Failed to create unique actors");
        check_equal(num_of_actors, n_actors + 3, "Expected two extra actors");
      elsif run("Test that no name actors can be created") then
        check(create /= null_actor_c, "Failed to create no name actor");
      elsif run("Expected to fail: Test that two actors of the same name cannot be created") then
        actor := create("actor2");
        actor := create("actor2");

      -- Find
      elsif run("Test that a created actor can be found") then
        actor := create("actor to be found");
        check(find("actor to be found", false) /= null_actor_c, "Failed to find created actor");
        check_equal(num_of_deferred_creations, 0, "Expected no deferred creations");
      elsif run("Test that an actor not created is found and its creation is deferred") then
        check_equal(num_of_deferred_creations, 0, "Expected no deferred creations");
        actor := find("actor with deferred creation");
        check(actor /= null_actor_c, "Failed to find actor with deferred creation");
        check_equal(num_of_deferred_creations, 1, "Expected one deferred creations");
      elsif run("Test that deferred creation can be suppressed when an actor is not found") then
        actor  := create("actor");
        actor2 := find("actor with deferred creation", false);
        check(actor2 = null_actor_c, "Didn't expect to find any actor");
        check_equal(num_of_deferred_creations, 0, "Expected no deferred creations");
      elsif run("Test that a created actor get the correct inbox size") then
        actor  := create("actor with max inbox");
        check(inbox_size(actor) = positive'high, "Expected maximum sized inbox");
        actor2 := create("actor with bounded inbox", 23);
        check(inbox_size(actor2) = 23, "Expected inbox size = 23");
        check(inbox_size(null_actor_c) = 0, "Expected no inbox on null actor");
        check(inbox_size(find("actor to be created")) = 1,
              "Expected inbox size on actor with deferred creation to be one");
        check(inbox_size(create("actor to be created", 42)) = 42,
              "Expected inbox size on actor with deferred creation to change to given value when created");

      -- Destroy
      elsif run("Test that a created actor can be destroyed") then
        actor    := create("actor to destroy");
        actor2   := create("actor to keep");
        n_actors := num_of_actors;
        destroy(actor);
        check(num_of_actors = n_actors - 1, "Expected one less actor");
        check(actor = null_actor_c, "Destroyed actor should be nullified");
        check(find("actor to destroy", false) = null_actor_c, "A destroyed actor should not be found");
        check(find("actor to keep", false) /= null_actor_c,
              "Actors other than the one destroyed must not be affected");
      elsif run("Expected to fail: Test that a non-existing actor cannot be destroyed") then
        actor := null_actor_c;
        destroy(actor);
      elsif run("Test that all actors can be destroyed") then
        reset_messenger;
        actor  := create("actor to destroy");
        actor2 := create("actor to destroy 2");
        check(num_of_actors = 2, "Expected two actors");
        reset_messenger;
        check(num_of_actors = 0, "Failed to destroy all actors");

      -- Messages
      elsif run("Test that a message can be deleted") then
        message := compose("hello");
        delete(message);
        check(message = null, "Message not deleted");

      -- Send and receive
      elsif run("Test that an actor can send a message to another actor") then
        start_receiver <= true;
        wait for 1 ns;
        receiver       := find("receiver");
        send(net, receiver, "hello world", receipt);
        check(receipt.status = ok, "Expected send to succeed");
        wait until hello_world_received for 1 ns;
        check(hello_world_received, "Expected ""hello world"" to be received at the server");
      elsif run("Test that an actor can send a message in response to another message from an a priori unknown actor") then
        start_server <= true;
        wait for 1 ns;
        server       := find("server");
        send(net, self, server, "request", receipt);
        receive(net, self, message);
        check(message.status = ok, "Expected no receive problems");
        check_equal(message.payload.all, "request acknowledge");
      elsif run("Test that an actor can send a message to itself") then
        send(net, self, "hello", receipt);
        receive(net, self, message);
        check(message.status = ok, "Expected no receive problems");
        check_equal(message.payload.all, "hello");
      elsif run("Test that sending without a receipt works") then
        send(net, self, "hello");
        receive(net, self, message);
        check_equal(message.payload.all, "hello");
        send(net, self, self, "hello again");
        receive(net, self, message);
        check_equal(message.payload.all, "hello again");
      elsif run("Test that an actor can poll for incoming messages") then
        wait_for_message(net, self, status, 0 ns);
        check(status = timeout, "Expected timeout");
        send(net, self, self, "hello again");
        wait_for_message(net, self, status, 0 ns);
        check(status = ok, "Expected ok status");
        message := get_message(self);
        check(message.status = ok, "Expected no problems with receive");
        check_equal(message.payload.all, "hello again");
        check(message.sender = self, "Expected message from myself");
      elsif run("Expected to fail: Test that sending to a non-existing actor results in an error") then
        send(net, null_actor_c, "hello void");
      elsif run("Test that an actor can send to an actor with deferred creation") then
        actor := find("deferred actor");
        send(net, actor, "hello actor to be created");
        check(receipt.status = ok, "Expected send to succeed");
        actor := create("deferred actor");
        receive(net, actor, message);
        check(message.status = ok, "Expected no problems with receive");
        check_equal(message.payload.all, "hello actor to be created");
      elsif run("Expected to fail: Test that receiving from an actor with deferred creation results in an error") then
        actor := find("deferred actor");
        receive(net, actor, message);
      elsif run("Test that empty messages can be sent") then
        send(net, self, "");
        receive(net, self, message);
        check(message.status = ok, "Expected no problems with receive");
        check_equal(message.payload.all, "");
      elsif run("Test that each sent message gets an increasing message number") then
        send(net, self, "", receipt);
        check(receipt.id = 1, "Expected first receipt id to be 1");
        send(net, self, "", receipt);
        check(receipt.id = 2, "Expected second receipt id to be 2");
        receive(net, self, message);
        check(message.id = 1, "Expected first message id to be 1");
        receive(net, self, message);
        check(message.id = 2, "Expected second message id to be 2");
      elsif run("Test that a limited-inbox receiver can receive as expected without blocking") then
        start_limited_inbox <= true;
        actor               := find("limited inbox");
        t_start             := now;
        send(net, actor, "First message");
        t_stop              := now;
        check_equal(t_stop - t_start, 0 ns, "Expected no blocking on first message");
        t_start             := now;
        send(net, actor, "Second message", 0 ns);
        t_stop              := now;
        check_equal(t_stop - t_start, 0 ns, "Expected no blocking on second message");
        t_start             := now;
        send(net, actor, "Third message", receipt, 11 ns);
        t_stop              := now;
        check_equal(t_stop - t_start, 10 ns, "Expected a 10 ns blocking period on third message");

        wait until limited_inbox_actor_done;
      elsif run("Expected to fail: Test that sending to a limited-inbox receiver times out as expected") then
        start_limited_inbox <= true;
        actor               := find("limited inbox");
        send(net, actor, "First message", receipt);
        send(net, actor, "Second message", receipt, 0 ns);
        send(net, actor, "Third message", receipt, 9 ns);

      -- Publish, subscribe, and unsubscribe
      elsif run("Test that an actor can publish messages to multiple subscribers") then
        publisher         := create("publisher");
        start_subscribers <= true;
        wait for 1 ns;
        publish(net, publisher, "hello subscriber");
        wait until hello_subscriber_received = "11" for 1 ns;
        check(hello_subscriber_received = "11", "Expected ""hello subscribers"" to be received at the subscribers");
      elsif run("Test that a subscriber can unsubscribe") then
        subscribe(self, self);
        publish(net, self, "hello subscriber");
        receive(net, self, message, 0 ns);
        check(message.status = ok, "Expected no problems with receive");
        check_equal(message.payload.all, "hello subscriber");
        unsubscribe(self, self);
        publish(net, self, "hello subscriber");
        wait_for_message(net, self, status, 0 ns);
        check(status = timeout, "Expected no message");
      elsif run("Test that a destroyed subscriber is not addressed by the publisher") then
        subscriber := create("subscriber");
        subscribe(subscriber, self);
        publish(net, self, "hello subscriber");
        receive(net, subscriber, message, 0 ns);
        check_equal(message.payload.all, "hello subscriber");
        destroy(subscriber);
        publish(net, self, "hello subscriber");
      elsif run("Expected to fail: Test that an actor can only subscribe once to the same publisher") then
        subscribe(self, self);
        subscribe(self, self);
      elsif run("Expected to fail: Test that publishing to subscribers with full inboxes results is an error") then
        start_limited_inbox_subscriber <= true;
        wait for 1 ns;
        publish(net, self, "hello subscribers");
        publish(net, self, "hello subscribers", 9 ns);
      elsif run("Test that publishing to subscribers with full inboxes results passes if waiting") then
        start_limited_inbox_subscriber <= true;
        wait for 1 ns;
        publish(net, self, "hello subscribers", 0 ns);
        publish(net, self, "hello subscribers", 11 ns);

      -- Request, (receive_)reply and acknowledge
      elsif run("Test that a client can wait for an out-of-order request reply") then
        start_server2 <= true;
        server        := find("server2");

        send(net, self, server, "request1", receipt);
        request_message := compose("request2", self);
        send(net, server, request_message);
        send(net, self, server, "request3", receipt3);

        receive_reply(net, request_message, reply_message);
        check_equal(reply_message.payload.all, "reply2");
        check_equal(reply_message.request_id, request_message.id);
        check(reply_message.sender = server, "Expected message to be from server");

        receive_reply(net, self, receipt, ack);
        check_false(ack, "Expected negative acknowledgement");

        receive_reply(net, self, receipt3, ack);
        check(ack, "Expected positive acknowledgement");
      elsif run("Test that a synchronous request can be made") then
        start_server3 <= true;
        server        := find("server3");

        request(net, self, server, "request1", reply_message);
        check_equal(reply_message.payload.all, "reply1");

        request(net, self, server, "request2", ack);
        check(ack, "Expected positive acknowledgement");

        request(net, self, server, "request3", ack);
        check_false(ack, "Expected negative acknowledgement");
      elsif run("Test waiting and getting a reply") then
        start_server4 <= true;
        server        := find("server4");

        t_start := now;
        send(net, self, server, "request1", receipt);
        wait_for_reply(net, self, receipt, status, 2 ns);
        check(status = timeout, "Expected timeout");
        check_equal(now - t_start, 2 ns);

        t_start         := now;
        request_message := compose("request2", self);
        send(net, server, request_message);
        wait_for_reply(net, request_message, status, 2 ns);
        check(status = timeout, "Expected timeout");
        check_equal(now - t_start, 2 ns);

        send(net, self, server, "request3", receipt);
        wait_for_reply(net, self, receipt, status);
        message := get_reply(self, receipt);
        check_equal(message.payload.all, "reply3");

        t_start         := now;
        request_message := compose("request4", self);
        send(net, server, request_message);
        wait_for_reply(net, request_message, status);
        get_reply(request_message, message);
        check_equal(message.payload.all, "reply4");

      -- Timeout
      elsif run("Expected to fail: Test that timeout on receive leads to an error") then
        receive(net, self, message, 1 ns);
      elsif run("Test that timeout errors can be suppressed") then
        allow_timeout;
        receive(net, self, message, 1 ns);

      -- Deprecated APIs
      elsif run("Expected to fail: Test that use of deprecated API leads to an error") then
        publish(net, self, "hello world", status);
      elsif run("Test that deprecated errors can be suppressed") then
        allow_deprecated;
        publish(net, self, "hello world", status);
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  test_runner_watchdog(runner, 100 ms);

  receiver : process is
    variable self    : actor_t;
    variable message : message_ptr_t;
    variable status  : com_status_t;
  begin
    wait until start_receiver;
    self                 := create("receiver");
    wait_for_message(net, self, status);
    message              := get_message(self);
    hello_world_received <= check_equal(message.payload.all, "hello world");
    wait;
  end process receiver;

  server : process is
    variable self    : actor_t;
    variable message : message_ptr_t;
    variable receipt : receipt_t;
  begin
    wait until start_server;
    self := create("server");
    receive(net, self, message);
    if check_equal(message.payload.all, "request") then
      send(net, message.sender, "request acknowledge", receipt);
    end if;
    wait;
  end process server;

  subscribers : for i in 1 to 2 generate
    process is
      variable self, publisher : actor_t;
      variable message         : message_ptr_t;
    begin
      wait until start_subscribers;
      self      := create("subscriber " & integer'image(i));
      publisher := find("publisher");
      subscribe(self, publisher);
      receive(net, self, message);
      if check_equal(message.payload.all, "hello subscriber") then
        hello_subscriber_received(i)     <= '1';
        hello_subscriber_received(3 - i) <= 'Z';
      end if;
      wait;
    end process;
  end generate subscribers;

  server2 : process is
    variable self                                                 : actor_t;
    variable request_message1, request_message2, request_message3 : message_ptr_t;
    variable reply_message                                        : message_ptr_t;
  begin
    wait until start_server2;
    self := create("server2");
    receive(net, self, request_message1);
    check_equal(request_message1.payload.all, "request1");
    receive(net, self, request_message2);
    check_equal(request_message2.payload.all, "request2");
    receive(net, self, request_message3);
    check_equal(request_message3.payload.all, "request3");

    reply_message := compose("reply2", self);
    reply(net, request_message2, reply_message);
    acknowledge(net, request_message3, true);
    acknowledge(net, request_message1, false);
    wait;
  end process server2;

  server3 : process is
    variable self            : actor_t;
    variable request_message : message_ptr_t;
  begin
    wait until start_server3;
    self := create("server3");

    receive(net, self, request_message);
    check_equal(request_message.payload.all, "request1");
    reply(net, request_message, "reply1");

    receive(net, self, request_message);
    check_equal(request_message.payload.all, "request2");
    acknowledge(net, request_message, true);

    receive(net, self, request_message);
    check_equal(request_message.payload.all, "request3");
    acknowledge(net, request_message, false);
    wait;
  end process server3;

  server4 : process is
    variable self            : actor_t;
    variable request_message : message_ptr_t;
  begin
    wait until start_server4;
    self := create("server4", 1);

    receive(net, self, request_message);
    receive(net, self, request_message);
    receive(net, self, request_message);
    reply(net, request_message, "reply3");
    receive(net, self, request_message);
    reply(net, request_message, "reply4");
    wait;
  end process server4;

  limited_inbox_actor : process is
    variable self, test_runner : actor_t;
    variable message           : message_ptr_t;
    variable status            : com_status_t;
  begin
    wait until start_limited_inbox;
    self                     := create("limited inbox", 2);
    test_runner              := find("test runner");
    wait for 10 ns;
    receive(net, self, message);
    receive(net, self, message);
    receive(net, self, message);
    limited_inbox_actor_done <= true;
    wait;
  end process limited_inbox_actor;

  limited_inbox_subscriber : process is
    variable self    : actor_t;
    variable message : message_ptr_t;
  begin
    wait until start_limited_inbox_subscriber;
    self := create("limited inbox subscriber", 1);
    subscribe(self, find("test runner"));
    wait for 10 ns;
    receive(net, self, message);
    wait;
  end process limited_inbox_subscriber;

end test_fixture;
