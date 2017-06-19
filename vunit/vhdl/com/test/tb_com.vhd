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
    start_server2, start_server3, start_subscribers : boolean := false;
  signal hello_subscriber_received                     : std_logic_vector(1 to 2) := "ZZ";
  signal start_limited_inbox, limited_inbox_actor_done : boolean                  := false;
  signal start_limited_inbox_subscriber                : boolean                  := false;
begin
  test_runner : process
    variable actor_to_be_found, actor_with_deferred_creation, actor_to_destroy,
      actor_to_destroy_copy, actor_to_keep, actor,
      self, receiver, server, deferred_actor, publisher, subscriber,
      limited_inbox, actor_with_max_inbox, actor_with_bounded_inbox : actor_t;
    variable status            : com_status_t;
    variable receipt, receipt2, receipt3 : receipt_t;
    variable n_actors          : natural;
    variable message           : message_ptr_t;
    variable reply_message     : message_ptr_t;
    variable t_start, t_stop   : time;
    variable ack               : boolean;
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
        check(create("actor") /= null_actor_c, "Failed to create named actor");
        check(num_of_actors = 2, "Expected two actors");
        check(create("other actor").id /= create("another actor").id, "Failed to create unique actors");
        check(num_of_actors = 4, "Expected four actors");
      elsif run("Test that no name actors can be created") then
        check(create /= null_actor_c, "Failed to create no name actor");
      elsif run("Expected to fail: Test that two actors of the same name cannot be created") then
        actor := create("actor2");
        actor := create("actor2");

      -- Find
      elsif run("Test that a created actor can be found") then
        actor_to_be_found := create("actor to be found");
        check(find("actor to be found", false) /= null_actor_c, "Failed to find created actor");
        check(num_of_deferred_creations = 0, "Expected no deferred creations");
      elsif run("Test that an actor not created is found and its creation is deferred") then
        check(num_of_deferred_creations = 0, "Expected no deferred creations");
        actor_with_deferred_creation := find("actor with deferred creation");
        check(actor_with_deferred_creation /= null_actor_c, "Failed to find actor with deferred creation");
        check(num_of_deferred_creations = 1, "Expected one deferred creations");
      elsif run("Test that deferred creation can be suppressed when an actor is not found") then
        actor := create("actor3");
        actor_with_deferred_creation := find("actor with deferred creation2", false);
        check(actor_with_deferred_creation = null_actor_c, "Didn't expect to find any actor");
        check(num_of_deferred_creations = 0, "Expected no deferred creations");
      elsif run("Test that a created actor get the correct inbox size") then
        actor_with_max_inbox     := create("actor with max inbox");
        check(inbox_size(actor_with_max_inbox) = positive'high, "Expected maximum sized inbox");
        actor_with_bounded_inbox := create("actor with bounded inbox", 23);
        check(inbox_size(actor_with_bounded_inbox) = 23, "Expected inbox size = 23");
        check(inbox_size(null_actor_c) = 0, "Expected no inbox on null actor");
        check(inbox_size(find("actor to be created")) = 1,
              "Expected inbox size on actor with deferred creation to be one");
        check(inbox_size(create("actor to be created", 42)) = 42,
              "Expected inbox size on actor with deferred creation to change to given value when created");

      -- Destroy
      elsif run("Test that a created actor can be destroyed") then
        actor_to_destroy := create("actor to destroy");
        actor_to_keep    := create("actor to keep");
        n_actors         := num_of_actors;
        destroy(actor_to_destroy);
        check(num_of_actors = n_actors - 1, "Expected one less actor");
        check(actor_to_destroy = null_actor_c, "Destroyed actor should be nullified");
        check(find("actor to destroy", false) = null_actor_c, "A destroyed actor should not be found");
        check(find("actor to keep", false) /= null_actor_c,
              "Actors other than the one destroyed must not be affected");
      elsif run("Expected to fail: Test that a non-existing actor cannot be destroyed") then
        actor := null_actor_c;
        destroy(actor);
      elsif run("Test that all actors can be destroyed") then
        reset_messenger;
        actor_to_destroy := create("actor to destroy 2");
        actor_to_destroy := create("actor to destroy 3");
        check(num_of_actors = 2, "Expected two actors");
        reset_messenger;
        check(num_of_actors = 0, "Failed to destroy all actors");

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
        check(receipt.status = ok, "Expected send to succeed");
        receive(net, self, message);
        if check(message.status = ok, "Expected no receive problems") then
          check(message.payload.all = "request acknowledge", "Expected ""request acknowledge """ & message.payload.all);
        end if;
        delete(message);
      elsif run("Test that an actor can send a message to itself") then
        send(net, self, "hello", receipt);
        check(receipt.status = ok, "Expected send to succeed");
        receive(net, self, message);
        if check(message.status = ok, "Expected no receive problems") then
          check(message.payload.all = "hello", "Expected ""hello""");
        end if;
        delete(message);
      elsif run("Test that sending without a receipt works") then
        send(net, self, "hello");
        receive(net, self, message);
        check(message.payload.all = "hello", "Expected ""hello""");
        send(net, self, self, "hello again");
        receive(net, self, message);
        check(message.payload.all = "hello again", "Expected ""hello again""");
        delete(message);
      elsif run("Test that an actor can poll for incoming messages") then
        receive(net, self, message, 0 ns);
        check(message.payload = null, "Expected no message payload");
        check(message.status = timeout, "Expected timeout");
        send(net, self, self, "hello again", receipt);
        check(receipt.status = ok, "Expected send to succeed");
        receive(net, self, message, 0 ns);
        if check(message.status = ok, "Expected no problems with receive") then
          check(message.payload.all = "hello again", "Expected ""hello again""");
          check(message.sender = self, "Expected message from myself");
        end if;
        delete(message);
      elsif run("Expected to fail: Test that sending to a non-existing actor results in an error") then
        send(net, null_actor_c, "hello void", receipt);
      elsif run("Test that an actor can send to an actor with deferred creation") then
        deferred_actor := find("deferred actor");
        send(net, deferred_actor, "hello actor to be created", receipt);
        check(receipt.status = ok, "Expected send to succeed");
        deferred_actor := create("deferred actor");
        receive(net, deferred_actor, message);
        if check(message.status = ok, "Expected no problems with receive") then
          check(message.payload.all = "hello actor to be created", "Expected ""hello actor to be created""");
        end if;
        delete(message);
      elsif run("Expected to fail: Test that receiving from an actor with deferred creation results in an error") then
        deferred_actor := find("deferred actor");
        receive(net, deferred_actor, message);
      elsif run("Test that empty messages can be sent") then
        send(net, self, "", receipt);
        check(receipt.status = ok, "Expected send to succeed");
        receive(net, self, message);
        if check(message.status = ok, "Expected no problems with receive") then
          check(message.payload.all = "", "Expected an empty message");
        end if;
        delete(message);
      elsif run("Test that each sent message gets an increasing message number") then
        send(net, self, "", receipt);
        check(receipt.id = 1, "Expected first receipt id to be 1");
        send(net, self, "", receipt);
        check(receipt.id = 2, "Expected second receipt id to be 2");
        receive(net, self, message);
        check(message.id = 1, "Expected first message id to be 1");
        receive(net, self, message);
        check(message.id = 2, "Expected second message id to be 2");
        delete(message);
      elsif run("Test that a limited-inbox receiver can receive as expected without blocking") then
        start_limited_inbox <= true;
        limited_inbox       := find("limited inbox");
        t_start             := now;
        send(net, limited_inbox, "First message", receipt);
        t_stop              := now;
        check(t_stop - t_start = 0 ns, "Expected no blocking on first message");
        t_start             := now;
        send(net, limited_inbox, "Second message", receipt, 0 ns);
        t_stop              := now;
        check(t_stop - t_start = 0 ns, "Expected no blocking on second message");
        t_start             := now;
        send(net, limited_inbox, "Third message", receipt, 11 ns);
        t_stop              := now;
        check(t_stop - t_start = 10 ns, "Expected a 10 ns blocking period on third message");

        wait until limited_inbox_actor_done;
      elsif run("Expected to fail: Test that sending to a limited-inbox receiver times out as expected") then
        start_limited_inbox <= true;
        limited_inbox       := find("limited inbox");
        send(net, limited_inbox, "First message", receipt);
        send(net, limited_inbox, "Second message", receipt, 0 ns);
        send(net, limited_inbox, "Third message", receipt, 9 ns);

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
        if check(message.status = ok, "Expected no problems with receive") then
          check(message.payload.all = "hello subscriber", "Expected a ""hello subscriber"" message");
        end if;
        unsubscribe(self, self);
        publish(net, self, "hello subscriber");
        receive(net, self, message, 0 ns);
        check(message.status = timeout, "Expected no message");
      elsif run("Test that a destroyed subscriber is not addressed by the publisher") then
        subscriber := create("subscriber");
        subscribe(subscriber, self);
        publish(net, self, "hello subscriber");
        receive(net, subscriber, message, 0 ns);
        if check(message.status = ok, "Expected no problems with receive") then
          check(message.payload.all = "hello subscriber", "Expected a ""hello subscriber"" message");
        end if;
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
        send(net, self, server, "request2", receipt2);
        send(net, self, server, "request3", receipt3);

        receive_reply(net, self, receipt2.id, reply_message);
        check(reply_message.payload.all = "reply2", "Expected ""reply2""");
        check(reply_message.request_id = receipt2.id, "Expected request_id = " & integer'image(receipt2.id) &
              " but got " & integer'image(reply_message.request_id));

        receive_reply(net, self, receipt.id, ack, status);
        check(status = ok, "Expected receive_reply to succeed");
        check_false(ack, "Expected negative acknowledgement");

        receive_reply(net, self, receipt3.id, ack);
        check(ack, "Expected positive acknowledgement");

        delete(reply_message);
      elsif run("Test that a synchronous request can be made") then
        start_server3 <= true;
        server        := find("server3");

        request(net, self, server, "request1", reply_message);
        check(reply_message.payload.all = "reply1", "Expected ""reply1""");
        delete(reply_message);

        request(net, self, server, "request2", ack, status);
        check(status = ok, "Expected request to succeed");
        check(ack, "Expected positive acknowledgement");

        request(net, self, server, "request3", ack);
        check(not ack, "Expected negative acknowledgement");

        t_start := now;
        request(net, self, server, "request4", reply_message, 3 ns);
        check(reply_message.status = timeout, "Expected timeout");
        check(now - t_start = 3 ns, "Expected timeout after 3 ns");
        delete(reply_message);

        send(net, self, server, "A message", receipt);
        send(net, self, server, "This will sit in the inbox for 3 ns", receipt);
        t_start := now;
        request(net, self, server,
                "The send part will block for 3 ns, the receive part should timout after 2 to get a total of 5 ns",
                reply_message, 5 ns);
        check(reply_message.status = timeout, "Expected timeout");
        check(now - t_start = 5 ns, "Expected timeout after 5 ns");
        delete(reply_message);
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
    self    := create("receiver");
    wait_for_messages(net, self, status);
    message := get_message(self);
    if check(message.payload.all = "hello world", "Expected ""hello world""") then
      hello_world_received <= true;
    end if;
    delete(message);
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
    if check(message.payload.all = "request", "Expected ""request""") then
      send(net, message.sender, "request acknowledge", receipt);
      check(receipt.status = ok, "Expected send to succeed");
    end if;
    delete(message);
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
      if check(message.payload.all = "hello subscriber", "Expected ""hello subscriber""") then
        hello_subscriber_received(i)     <= '1';
        hello_subscriber_received(3 - i) <= 'Z';
      end if;
      delete(message);
      wait;
    end process;
  end generate subscribers;

  server2 : process is
    variable self                               : actor_t;
    variable request_message1, request_message2, request_message3 : message_ptr_t;
  begin
    wait until start_server2;
    self := create("server2");
    receive(net, self, request_message1);
    check(request_message1.payload.all = "request1", "Expected ""request1""");
    receive(net, self, request_message2);
    check(request_message2.payload.all = "request2", "Expected ""request2""");
    receive(net, self, request_message3);
    check(request_message3.payload.all = "request3", "Expected ""request3""");

    reply(net, request_message2.sender, request_message2.id, "reply2");
    acknowledge(net, request_message3.sender, request_message3.id, true);
    acknowledge(net, request_message1.sender, request_message1.id, false);

    delete(request_message1);
    delete(request_message2);
    wait;
  end process server2;

  server3 : process is
    variable self            : actor_t;
    variable request_message : message_ptr_t;
  begin
    wait until start_server3;
    self := create("server3", 1);

    receive(net, self, request_message);
    check(request_message.payload.all = "request1", "Expected ""request1""");
    reply(net, request_message.sender, request_message.id, "reply1");
    delete(request_message);

    receive(net, self, request_message);
    check(request_message.payload.all = "request2", "Expected ""request2""");
    acknowledge(net, request_message.sender, request_message.id, true);
    delete(request_message);

    receive(net, self, request_message);
    acknowledge(net, request_message.sender, request_message.id, false);
    delete(request_message);

    receive(net, self, request_message);
    delete(request_message);

    receive(net, self, request_message);
    wait for 3 ns;
    receive(net, self, request_message);
    delete(request_message);
    wait;
  end process server3;

  limited_inbox_actor : process is
    variable self, test_runner  : actor_t;
    variable message            : message_ptr_t;
    variable status             : com_status_t;
  begin
    wait until start_limited_inbox;
    self                     := create("limited inbox", 2);
    test_runner              := find("test runner");
    wait for 10 ns;
    receive(net, self, message);
    receive(net, self, message);
    receive(net, self, message);
    delete(message);
    limited_inbox_actor_done <= true;
    wait;
  end process limited_inbox_actor;

  limited_inbox_subscriber : process is
    variable self : actor_t;
    variable message           : message_ptr_t;
  begin
    wait until start_limited_inbox_subscriber;
    self := create("limited inbox subscriber", 1);
    subscribe(self, find("test runner"));
    wait for 10 ns;
    receive(net, self, message);
    wait;
  end process limited_inbox_subscriber;

end test_fixture;
