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
use work.com_common_pkg.all;

use std.textio.all;

package body com_pkg is
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
  -- Message related subprograms
  -----------------------------------------------------------------------------
  impure function new_message (sender : actor_t := null_actor_c) return message_ptr_t is
    variable message : message_ptr_t;
  begin
    message            := new message_t;
    message.sender     := sender;
    return message;
  end function;

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

  procedure copy (src : inout message_ptr_t; dst : inout message_ptr_t) is
  begin
    dst := new message_t;
    dst.id := src.id;
    dst.status := src.status;
    dst.sender := src.sender;
    dst.request_id := src.request_id;
    write(dst.payload, src.payload.all);
  end procedure copy;

  procedure delete (message : inout message_ptr_t) is
  begin
    if message /= null then
      deallocate(message.payload);
      deallocate(message);
    end if;
  end procedure delete;

  -----------------------------------------------------------------------------
  -- Primary send and receive related subprograms
  -----------------------------------------------------------------------------
  procedure send (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant mailbox_name : in mailbox_name_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := true) is
    variable receipt : receipt_t;
  begin
    check(message /= null, null_message_error);
    check(not messenger.unknown_actor(receiver), unknown_receiver_error);

    if messenger.is_full(receiver, mailbox_name) then
      wait on net until not messenger.is_full(receiver, mailbox_name) for timeout;
      check(not messenger.is_full(receiver, mailbox_name), full_inbox_error);
    end if;

    messenger.send(message.sender, receiver, mailbox_name, message.request_id, message.payload.all, receipt);
    message.id := receipt.id;
    message.receiver := receiver;
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
    constant keep_message : in    boolean := true) is
    variable receipt : receipt_t;
  begin
    send(net, receiver, inbox, message, timeout, keep_message);
  end;

  procedure receive (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable message  : inout message_ptr_t;
    constant timeout  : in    time := max_timeout_c) is
    variable status                  : com_status_t;
    variable started_with_full_inbox : boolean;
  begin
    delete(message);
    wait_for_message(net, receiver, status, timeout);
    check(no_error_status(status), status);
    if status = ok then
      started_with_full_inbox := messenger.is_full(receiver, inbox);
      message                 := get_message(receiver);
      if started_with_full_inbox then
        notify(net);
      end if;
    else
      message        := new message_t;
      message.receiver := receiver;
      message.status := status;
    end if;
  end;

  procedure reply (
    signal net            : inout network_t;
    variable request   : inout    message_ptr_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := true) is
  begin
    check(request.id /= no_message_id_c, reply_missing_request_id_error);
    message.request_id := request.id;
    message.sender := request.receiver;

    if request.sender /= null_actor_c then
      send(net, request.sender, inbox, message, timeout, keep_message);
    else
      send(net, request.receiver, outbox, message, timeout, keep_message);
    end if;
  end;

  procedure receive_reply (
    signal net          : inout network_t;
    variable request    : inout    message_ptr_t;
    variable message    : inout message_ptr_t;
    constant timeout    : in    time := max_timeout_c) is
    variable status : com_status_t;
    variable source_actor : actor_t;
    variable mailbox : mailbox_name_t;
  begin
    delete(message);

    source_actor := request.sender when request.sender /= null_actor_c else request.receiver;
    mailbox := inbox when request.sender /= null_actor_c else outbox;

    wait_for_reply_stash_message(net, source_actor, mailbox, request.id, status, timeout);
    check(no_error_status(status), status);
    if status = ok then
      message := get_reply_stash_message(source_actor);
    else
      message        := new message_t;
      message.receiver := request.sender;
      message.status := status;
    end if;
  end;

  procedure publish (
    signal net            : inout network_t;
    constant sender : in    actor_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := true) is
  begin
    check(message /= null, null_message_error);
    message.sender := sender;
    message.receiver := null_actor_c;

    if messenger.subscriber_inbox_is_full(message.sender) then
      wait on net until not messenger.subscriber_inbox_is_full(sender) for timeout;
      check(not messenger.subscriber_inbox_is_full(message.sender), full_inbox_error);
    end if;

    messenger.publish(message.sender, message.payload.all);
    notify(net);

    if not keep_message then
      delete(message);
    end if;
  end;

  -----------------------------------------------------------------------------
  -- Secondary send and receive related subprograms
  -----------------------------------------------------------------------------

  procedure request (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    variable request_message : inout message_ptr_t;
    variable reply_message   : inout message_ptr_t;
    constant timeout         : in    time    := max_timeout_c;
    constant keep_message    : in    boolean := false) is
    variable start   : time;
  begin
    start := now;
    send(net, receiver, request_message, timeout, keep_message => true);
    receive_reply(net, request_message, reply_message, timeout - (now - start));
    if not keep_message then
      delete(request_message);
    end if;
  end;

  procedure request (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    variable request_message : inout message_ptr_t;
    variable positive_ack    : out   boolean;
    constant timeout         : in    time    := max_timeout_c;
    constant keep_message    : in    boolean := false) is
    variable start   : time;
  begin
    start := now;
    send(net, receiver, request_message, timeout, keep_message => true);
    receive_reply(net, request_message, positive_ack, timeout - (now - start));
    if not keep_message then
      delete(request_message);
    end if;
  end;

  procedure publish (
    signal net            : inout network_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false) is
  begin
    publish(net, message.sender, message, timeout, keep_message);
  end;

  procedure acknowledge (
    signal net            : inout network_t;
    variable request   : inout    message_ptr_t;
    constant positive_ack : in    boolean := true;
    constant timeout      : in    time    := max_timeout_c) is
    variable receipt      : receipt_t;
    variable message : message_ptr_t;
  begin
    check(request.id /= no_message_id_c, reply_missing_request_id_error);
    message := compose(encode(positive_ack), request_id => request.id);
    send(net, request.sender, message, timeout);
  end;

  procedure receive_reply (
    signal net            : inout network_t;
    variable request    : inout    message_ptr_t;
    variable positive_ack : out   boolean;
    constant timeout      : in    time := max_timeout_c) is
    constant receipt : receipt_t := (status => ok, id => request.id);
    variable message : message_ptr_t;
  begin
    receive_reply(net, request, message, timeout);
    positive_ack := decode(message.payload.all);
    delete(message);
  end;

  -----------------------------------------------------------------------------
  -- Low-level subprograms primarily used for handling timeout wihout error
  -----------------------------------------------------------------------------
  procedure wait_for_message (
    signal net               : in  network_t;
    constant receiver        : in  actor_t;
    variable status          : out com_status_t;
    constant timeout : in  time := max_timeout_c) is
  begin
    check(not messenger.deferred(receiver), deferred_receiver_error);

    status := ok;
    if not messenger.has_messages(receiver) then
      wait on net until messenger.has_messages(receiver) for timeout;
      if not messenger.has_messages(receiver) then
        status := work.com_types_pkg.timeout;
      end if;
    end if;
  end procedure wait_for_message;

  procedure wait_for_reply (
    signal net               : inout network_t;
    variable request  : inout message_ptr_t;
    variable status          : out   com_status_t;
    constant timeout : in    time := max_timeout_c) is
  begin
    wait_for_reply_stash_message(net, request.sender, inbox, request.id, status, timeout);
  end;

  procedure wait_for_reply (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    constant receipt  : in receipt_t;
    variable status          : out   com_status_t;
    constant timeout : in    time := max_timeout_c) is
  begin
    wait_for_reply_stash_message(net, receiver, inbox, receipt.id, status, timeout);
  end;

  impure function has_message (actor : actor_t) return boolean is
  begin
    return messenger.has_messages(actor);
  end function has_message;

  impure function get_message (receiver : actor_t; delete_from_inbox : boolean := true) return message_ptr_t is
    variable message : message_ptr_t;
  begin
    check(messenger.has_messages(receiver), null_message_error);

    message            := new message_t;
    message.status     := ok;
    message.id         := messenger.get_first_message_id(receiver);
    message.request_id := messenger.get_first_message_request_id(receiver);
    message.sender     := messenger.get_first_message_sender(receiver);
    message.receiver   := receiver;
    write(message.payload, messenger.get_first_message_payload(receiver));
    if delete_from_inbox then
      messenger.delete_first_envelope(receiver);
    end if;

    return message;
  end function get_message;

  impure function get_reply (
    receiver : actor_t;
    receipt : receipt_t;
    delete_from_inbox : boolean := true)
    return message_ptr_t is
  begin
    check(messenger.get_reply_stash_message_request_id(receiver) = receipt.id, unknown_request_id_error);

    return get_reply_stash_message(receiver, delete_from_inbox);
  end;

  procedure get_reply (
    variable request           : inout message_ptr_t;
    variable reply             : inout message_ptr_t;
    constant delete_from_inbox : in    boolean := true) is
  begin
    check(messenger.get_reply_stash_message_request_id(request.sender) = request.id, unknown_request_id_error);
    reply := get_reply_stash_message(request.sender, delete_from_inbox);
  end;

  -----------------------------------------------------------------------------
  -- Subscriptions
  -----------------------------------------------------------------------------
  procedure subscribe (subscriber : actor_t; publisher : actor_t) is
  begin
    messenger.subscribe(subscriber, publisher);
  end procedure subscribe;

  procedure unsubscribe (subscriber : actor_t; publisher : actor_t) is
  begin
    messenger.unsubscribe(subscriber, publisher);
  end procedure unsubscribe;

  -----------------------------------------------------------------------------
  -- Misc
  -----------------------------------------------------------------------------
  procedure allow_timeout is
  begin
    messenger.allow_timeout;
  end;

  procedure allow_deprecated is
  begin
    messenger.allow_deprecated;
  end;

  procedure deprecated (msg : string) is
  begin
    messenger.deprecated(msg);
  end;

end package body com_pkg;
