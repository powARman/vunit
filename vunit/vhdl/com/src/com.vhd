-- Com package provides a generic communication mechanism for testbenches
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015-2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

use work.com_codec_pkg.all;
use work.com_support_pkg.all;
use work.com_messenger_pkg.all;

use std.textio.all;

package body com_pkg is
  shared variable messenger : messenger_t;

  -----------------------------------------------------------------------------
  -- Handling of actors
  -----------------------------------------------------------------------------
  impure function create (name : string := ""; inbox_size : positive := positive'high) return actor_t is
  begin
    return messenger.create(name, inbox_size);
  end;

  impure function find (name : string; enable_deferred_creation : boolean := true) return actor_t is
  begin
    return messenger.find(name, enable_deferred_creation);
  end;

  procedure destroy (actor : inout actor_t; status : out com_status_t) is
  begin
    deprecated("destroy() with status output");
    status := ok;
    messenger.destroy(actor);
  end;

  procedure destroy (actor : inout actor_t) is
  begin
    messenger.destroy(actor);
  end;

  procedure reset_messenger is
  begin
    messenger.reset_messenger;
  end;

  impure function num_of_actors
    return natural is
  begin
    return messenger.num_of_actors;
  end;

  impure function num_of_deferred_creations
    return natural is
  begin
    return messenger.num_of_deferred_creations;
  end;

  impure function inbox_size (actor : actor_t) return natural is
  begin
    return messenger.inbox_size(actor);
  end;

  -----------------------------------------------------------------------------
  -- Network related
  -----------------------------------------------------------------------------
  procedure notify (signal net : inout network_t) is
  begin
    if net /= network_event then
      net <= network_event;
      wait until net = network_event;
      net <= idle_network;
    end if;
  end procedure notify;

  -----------------------------------------------------------------------------
  -- Send related subprograms
  -----------------------------------------------------------------------------
  procedure send (
    signal net        : inout network_t;
    constant sender   : in    actor_t;
    constant receiver : in    actor_t;
    constant payload  : in    string := "";
    variable receipt  : out   receipt_t;
    constant timeout  : in    time   := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    message := compose(payload, sender);
    send(net, receiver, message, receipt, timeout);
  end;

  procedure send (
    signal net        : inout network_t;
    constant sender   : in    actor_t;
    constant receiver : in    actor_t;
    constant payload  : in    string := "";
    constant timeout  : in    time   := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    message := compose(payload, sender);
    send(net, receiver, message, timeout);
  end;

  procedure send (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    constant payload  : in    string := "";
    variable receipt  : out   receipt_t;
    constant timeout  : in    time   := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    message := compose(payload);
    send(net, receiver, message, receipt, timeout);
  end;

  procedure send (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    constant payload  : in    string := "";
    constant timeout  : in    time   := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    message := compose(payload);
    send(net, receiver, message, timeout);
  end;

  procedure send (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable message      : inout message_ptr_t;
    variable receipt      : out   receipt_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false) is
  begin
    check(message /= null, null_message_error);
    check(not messenger.unknown_actor(receiver), unknown_receiver_error);

    if messenger.inbox_is_full(receiver) then
      wait on net until not messenger.inbox_is_full(receiver) for timeout;
      check(not messenger.inbox_is_full(receiver), full_inbox_error);
    end if;

    messenger.send(message.sender, receiver, message.request_id, message.payload.all, receipt);
    notify(net);

    if not keep_message then
      delete(message);
    end if;
  end;

  procedure send (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false) is
    variable receipt : receipt_t;
  begin
    send(net, receiver, message, receipt, timeout, keep_message);
  end;

  procedure request (
    signal net               : inout network_t;
    constant sender          : in    actor_t;
    constant receiver        : in    actor_t;
    constant request_payload : in    string := "";
    variable reply_message   : inout message_ptr_t;
    constant timeout         : in    time   := max_timeout_c) is
    variable request_message : message_ptr_t;
  begin
    request_message := compose(request_payload, sender);
    request(net, receiver, request_message, reply_message, timeout);
  end;

  procedure request (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    variable request_message : inout message_ptr_t;
    variable reply_message   : inout message_ptr_t;
    constant timeout         : in    time    := max_timeout_c;
    constant keep_message    : in    boolean := false) is
    variable receipt : receipt_t;
    variable start   : time;
    constant sender  : actor_t := request_message.sender;
  begin
    start := now;
    send(net, receiver, request_message, receipt, timeout, keep_message);
    if receipt.status = ok then
      receive_reply(net, sender, receipt.id, reply_message, timeout - (now - start));
    else
      reply_message.status := receipt.status;
    end if;
  end;

  procedure request (
    signal net               : inout network_t;
    constant sender          : in    actor_t;
    constant receiver        : in    actor_t;
    constant request_payload : in    string := "";
    variable positive_ack    : out   boolean;
    variable status          : out   com_status_t;
    constant timeout         : in    time   := max_timeout_c) is
    variable request_message : message_ptr_t;
  begin
    request_message := compose(request_payload, sender);
    request(net, receiver, request_message, positive_ack, status, timeout);
  end;

  procedure request (
    signal net               : inout network_t;
    constant sender          : in    actor_t;
    constant receiver        : in    actor_t;
    constant request_payload : in    string := "";
    variable positive_ack    : out   boolean;
    constant timeout         : in    time   := max_timeout_c) is
    variable request_message : message_ptr_t;
  begin
    request_message := compose(request_payload, sender);
    request(net, receiver, request_message, positive_ack, timeout);
  end;

  procedure request (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    variable request_message : inout message_ptr_t;
    variable positive_ack    : out   boolean;
    variable status          : out   com_status_t;
    constant timeout         : in    time    := max_timeout_c;
    constant keep_message    : in    boolean := false) is
    variable receipt : receipt_t;
    variable start   : time;
    constant sender  : actor_t := request_message.sender;
  begin
    start := now;
    send(net, receiver, request_message, receipt, timeout, keep_message);
    if receipt.status = ok then
      receive_reply(net, sender, receipt.id, positive_ack, status, timeout - (now - start));
    else
      status       := receipt.status;
      positive_ack := false;
    end if;
  end;

  procedure request (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    variable request_message : inout message_ptr_t;
    variable positive_ack    : out   boolean;
    constant timeout         : in    time    := max_timeout_c;
    constant keep_message    : in    boolean := false) is
    variable status : com_status_t;
  begin
    request(net, receiver, request_message, positive_ack, status, timeout, keep_message);
  end;

  procedure reply (
    signal net          : inout network_t;
    constant sender     : in    actor_t;
    constant receiver   : in    actor_t;
    constant request_id : in    message_id_t;
    constant payload    : in    string := "";
    variable receipt    : out   receipt_t;
    constant timeout    : in    time   := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    message := compose(payload, sender, request_id);
    reply(net, receiver, message, receipt, timeout);
  end;

  procedure reply (
    signal net          : inout network_t;
    constant sender     : in    actor_t;
    constant receiver   : in    actor_t;
    constant request_id : in    message_id_t;
    constant payload    : in    string := "";
    constant timeout    : in    time   := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    message := compose(payload, sender, request_id);
    reply(net, receiver, message, timeout);
  end;

  procedure reply (
    signal net          : inout network_t;
    constant receiver   : in    actor_t;
    constant request_id : in    message_id_t;
    constant payload    : in    string := "";
    variable receipt    : out   receipt_t;
    constant timeout    : in    time   := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    message := compose(payload, request_id => request_id);
    reply(net, receiver, message, receipt, timeout);
  end;

  procedure reply (
    signal net          : inout network_t;
    constant receiver   : in    actor_t;
    constant request_id : in    message_id_t;
    constant payload    : in    string := "";
    constant timeout    : in    time   := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    message := compose(payload, request_id => request_id);
    reply(net, receiver, message, timeout);
  end;

  procedure reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable message      : inout message_ptr_t;
    variable receipt      : out   receipt_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false) is
  begin
    check(message.request_id /= no_message_id_c, reply_missing_request_id_error);

    send(net, receiver, message, receipt, timeout, keep_message);
  end;

  procedure reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false) is
    variable receipt : receipt_t;
  begin
    reply(net, receiver, message, receipt, timeout, keep_message);
  end;

  procedure acknowledge (
    signal net            : inout network_t;
    constant sender       : in    actor_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    constant positive_ack : in    boolean := true;
    variable receipt      : out   receipt_t;
    constant timeout      : in    time    := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    message := compose(encode(positive_ack), sender, request_id);
    send(net, receiver, message, receipt, timeout);
  end;

  procedure acknowledge (
    signal net            : inout network_t;
    constant sender       : in    actor_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    constant positive_ack : in    boolean := true;
    constant timeout      : in    time    := max_timeout_c) is
    variable message : message_ptr_t;
    variable receipt : receipt_t;
  begin
    acknowledge(net, sender, receiver, request_id, positive_ack, receipt, timeout);
  end;

  procedure acknowledge (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    constant positive_ack : in    boolean := true;
    variable receipt      : out   receipt_t;
    constant timeout      : in    time    := max_timeout_c) is
  begin
    acknowledge(net, null_actor_c, receiver, request_id, positive_ack, receipt, timeout);
  end;

  procedure acknowledge (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    constant positive_ack : in    boolean := true;
    constant timeout      : in    time    := max_timeout_c) is
  begin
    acknowledge(net, null_actor_c, receiver, request_id, positive_ack, timeout);
  end;

  procedure publish (
    signal net       : inout network_t;
    constant sender  : in    actor_t;
    constant payload : in    string := "";
    variable status  : out   com_status_t;
    constant timeout : in    time   := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    deprecated("publish() with status output");
    status  := ok;
    message := compose(payload, sender);
    publish(net, message, status, timeout);
  end;

  procedure publish (
    signal net       : inout network_t;
    constant sender  : in    actor_t;
    constant payload : in    string := "";
    constant timeout : in    time   := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    message := compose(payload, sender);
    publish(net, message, timeout);
  end;

  procedure publish (
    signal net            : inout network_t;
    variable message      : inout message_ptr_t;
    variable status       : out   com_status_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false) is
  begin
    deprecated("publish() with status output");
    check(message /= null, null_message_error);

    status := ok;
    if messenger.subscriber_inbox_is_full(message.sender) then
      wait on net until not messenger.subscriber_inbox_is_full(message.sender) for timeout;
      check(not messenger.subscriber_inbox_is_full(message.sender), full_inbox_error);
    end if;

    messenger.publish(message.sender, message.payload.all);
    notify(net);

    if not keep_message then
      delete(message);
    end if;
  end;

  procedure publish (
    signal net            : inout network_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false) is
    variable status : com_status_t;
  begin
    publish(net, message, status, timeout, keep_message);
  end;

  -----------------------------------------------------------------------------
  -- Receive related subprograms
  -----------------------------------------------------------------------------
  procedure wait_for_messages (
    signal net               : in  network_t;
    constant receiver        : in  actor_t;
    variable status          : out com_status_t;
    constant receive_timeout : in  time := max_timeout_c) is
  begin
    check(not messenger.deferred(receiver), deferred_receiver_error);

    status := ok;
    if not messenger.has_messages(receiver) then
      wait on net until messenger.has_messages(receiver) for receive_timeout;
      if not messenger.has_messages(receiver) then
        status := timeout;
      end if;
    end if;
  end procedure wait_for_messages;

  impure function has_messages (actor : actor_t) return boolean is
  begin
    return messenger.has_messages(actor);
  end function has_messages;

  impure function get_message (receiver : actor_t; delete_from_inbox : boolean := true) return message_ptr_t is
    variable message : message_ptr_t;
  begin
    check(messenger.has_messages(receiver), null_message_error);

    message            := new message_t;
    message.status     := ok;
    message.id         := messenger.get_first_message_id(receiver);
    message.request_id := messenger.get_first_message_request_id(receiver);
    message.sender     := messenger.get_first_message_sender(receiver);
    write(message.payload, messenger.get_first_message_payload(receiver));
    if delete_from_inbox then
      messenger.delete_first_envelope(receiver);
    end if;

    return message;
  end function get_message;

  procedure receive (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable message  : inout message_ptr_t;
    constant timeout  : in    time := max_timeout_c) is
    variable status                  : com_status_t;
    variable started_with_full_inbox : boolean;
  begin
    delete(message);
    wait_for_messages(net, receiver, status, timeout);
    if status = ok then
      started_with_full_inbox := messenger.inbox_is_full(receiver);
      message                 := get_message(receiver);
      if started_with_full_inbox then
        notify(net);
      end if;
    else
      message        := new message_t;
      message.status := status;
    end if;
  end;

  procedure wait_for_reply_stash_message (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    constant request_id      : in    message_id_t;
    variable status          : out   com_status_t;
    constant receive_timeout : in    time := max_timeout_c) is
    variable started_with_full_inbox : boolean;
  begin
    check(not messenger.deferred(receiver), deferred_receiver_error);

    status                  := ok;
    started_with_full_inbox := messenger.inbox_is_full(receiver);
    if messenger.has_reply_stash_message(receiver, request_id) then
      return;
    elsif messenger.find_and_stash_reply_message(receiver, request_id) then
      if started_with_full_inbox then
        notify(net);
      end if;
      return;
    else
      wait on net until messenger.find_and_stash_reply_message(receiver, request_id) for receive_timeout;
      if not messenger.has_reply_stash_message(receiver, request_id) then
        status := timeout;
      elsif started_with_full_inbox then
        notify(net);
      end if;
    end if;
  end procedure wait_for_reply_stash_message;

  impure function get_reply_stash_message (
    receiver : actor_t;
    clear_reply_stash : boolean := true)
    return message_ptr_t is
    variable message : message_ptr_t;
  begin
    check(messenger.has_reply_stash_message(receiver), null_message_error);

    message            := new message_t;
    message.status     := ok;
    message.id         := messenger.get_reply_stash_message_id(receiver);
    message.request_id := messenger.get_reply_stash_message_request_id(receiver);
    message.sender     := messenger.get_reply_stash_message_sender(receiver);
    write(message.payload, messenger.get_reply_stash_message_payload(receiver));
    if clear_reply_stash then
      messenger.clear_reply_stash(receiver);
    end if;

    return message;
  end function get_reply_stash_message;

  procedure receive_reply (
    signal net          : inout network_t;
    constant receiver   : in    actor_t;
    constant request_id : in    message_id_t;
    variable message    : inout message_ptr_t;
    constant timeout    : in    time := max_timeout_c) is
    variable status : com_status_t;
  begin
    delete(message);
    wait_for_reply_stash_message(net, receiver, request_id, status, timeout);
    if status = ok then
      message := get_reply_stash_message(receiver);
    else
      message        := new message_t;
      message.status := status;
    end if;
  end;

  procedure receive_reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    variable positive_ack : out   boolean;
    variable status       : out   com_status_t;
    constant timeout      : in    time := max_timeout_c) is
    variable message : message_ptr_t;
  begin
    receive_reply(net, receiver, request_id, message, timeout);
    if message.status = ok then
      positive_ack := decode(message.payload.all);
    else
      positive_ack := false;
    end if;

    status := message.status;
  end;

  procedure receive_reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    variable positive_ack : out   boolean;
    constant timeout      : in    time := max_timeout_c) is
    variable message : message_ptr_t;
    variable status  : com_status_t;
  begin
    receive_reply(net, receiver, request_id, positive_ack, status, timeout);
  end;

  procedure subscribe (
    constant subscriber : in  actor_t;
    constant publisher  : in  actor_t;
    variable status     : out com_status_t) is
  begin
    deprecated("subscribe() with status output");
    status := ok;
    messenger.subscribe(subscriber, publisher);
  end procedure subscribe;

  procedure subscribe (subscriber : actor_t; publisher : actor_t) is
  begin
    messenger.subscribe(subscriber, publisher);
  end procedure subscribe;

  procedure unsubscribe (
    constant subscriber : in  actor_t;
    constant publisher  : in  actor_t;
    variable status     : out com_status_t) is
  begin
    deprecated("subscribe() with status output");
    status := ok;
    messenger.unsubscribe(subscriber, publisher);
  end procedure unsubscribe;

  procedure unsubscribe (subscriber : actor_t; publisher : actor_t) is
  begin
    messenger.unsubscribe(subscriber, publisher);
  end procedure unsubscribe;

  impure function num_of_missed_messages (actor : actor_t) return natural is
  begin
    deprecated("num_of_missed_messages(). Missed messages not allowed.");
    return 0;
  end num_of_missed_messages;

  -----------------------------------------------------------------------------
  -- Message related subprograms
  -----------------------------------------------------------------------------
  impure function compose (
    payload    : string       := "";
    sender     : actor_t      := null_actor_c;
    request_id : message_id_t := no_message_id_c)
    return message_ptr_t is
    variable message : message_ptr_t;
  begin
    message            := new message_t;
    message.sender     := sender;
    message.request_id := request_id;
    write(message.payload, payload);
    return message;
  end function compose;

  procedure delete (message : inout message_ptr_t) is
  begin
    if message /= null then
      deallocate(message.payload);
      deallocate(message);
    end if;
  end procedure delete;

end package body com_pkg;
