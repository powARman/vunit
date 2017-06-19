-- Com API package provides the common API for all
-- implementations of the com functionality (VHDL 2002+ and VHDL 1993)
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2015-2017, Lars Asplund lars.anders.asplund@gmail.com

use work.com_types_pkg.all;

package com_pkg is
  signal net : network_t := idle_network;

  -----------------------------------------------------------------------------
  -- Handling of actors
  -----------------------------------------------------------------------------
  impure function create (name : string := ""; inbox_size : positive := positive'high) return actor_t;  --
  impure function find (name : string; enable_deferred_creation : boolean := true) return actor_t;

  procedure destroy (actor : inout actor_t; status : out com_status_t);
  procedure destroy (actor : inout actor_t);
  procedure reset_messenger;

  impure function num_of_actors return natural;
  impure function num_of_deferred_creations return natural;
  impure function inbox_size (actor : actor_t) return natural;

  -----------------------------------------------------------------------------
  -- Send related subprograms
  -----------------------------------------------------------------------------
  procedure send (
    signal net        : inout network_t;
    constant sender   : in    actor_t;
    constant receiver : in    actor_t;
    constant payload  : in    string := "";
    variable receipt  : out   receipt_t;
    constant timeout  : in    time   := max_timeout_c);
  procedure send (
    signal net        : inout network_t;
    constant sender   : in    actor_t;
    constant receiver : in    actor_t;
    constant payload  : in    string := "";
    constant timeout  : in    time   := max_timeout_c);
  procedure send (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    constant payload  : in    string := "";
    variable receipt  : out   receipt_t;
    constant timeout  : in    time   := max_timeout_c);
  procedure send (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    constant payload  : in    string := "";
    constant timeout  : in    time   := max_timeout_c);
  procedure send (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable message      : inout message_ptr_t;
    variable receipt      : out   receipt_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false);
  procedure send (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false);
  procedure request (
    signal net               : inout network_t;
    constant sender          : in    actor_t;
    constant receiver        : in    actor_t;
    constant request_payload : in    string := "";
    variable reply_message   : inout message_ptr_t;
    constant timeout         : in    time   := max_timeout_c);
  procedure request (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    variable request_message : inout message_ptr_t;
    variable reply_message   : inout message_ptr_t;
    constant timeout         : in    time    := max_timeout_c;
    constant keep_message    : in    boolean := false);
  procedure request (
    signal net               : inout network_t;
    constant sender          : in    actor_t;
    constant receiver        : in    actor_t;
    constant request_payload : in    string := "";
    variable positive_ack    : out   boolean;
    variable status          : out   com_status_t;
    constant timeout         : in    time   := max_timeout_c);
  procedure request (
    signal net               : inout network_t;
    constant sender          : in    actor_t;
    constant receiver        : in    actor_t;
    constant request_payload : in    string := "";
    variable positive_ack    : out   boolean;
    constant timeout         : in    time   := max_timeout_c);
  procedure request (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    variable request_message : inout message_ptr_t;
    variable positive_ack    : out   boolean;
    variable status          : out   com_status_t;
    constant timeout         : in    time    := max_timeout_c;
    constant keep_message    : in    boolean := false);
  procedure request (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    variable request_message : inout message_ptr_t;
    variable positive_ack    : out   boolean;
    constant timeout         : in    time    := max_timeout_c;
    constant keep_message    : in    boolean := false);
  procedure reply (
    signal net          : inout network_t;
    constant sender     : in    actor_t;
    constant receiver   : in    actor_t;
    constant request_id : in    message_id_t;
    constant payload    : in    string := "";
    variable receipt    : out   receipt_t;
    constant timeout    : in    time   := max_timeout_c);
  procedure reply (
    signal net          : inout network_t;
    constant sender     : in    actor_t;
    constant receiver   : in    actor_t;
    constant request_id : in    message_id_t;
    constant payload    : in    string := "";
    constant timeout    : in    time   := max_timeout_c);
  procedure reply (
    signal net          : inout network_t;
    constant receiver   : in    actor_t;
    constant request_id : in    message_id_t;
    constant payload    : in    string := "";
    variable receipt    : out   receipt_t;
    constant timeout    : in    time   := max_timeout_c);
  procedure reply (
    signal net          : inout network_t;
    constant receiver   : in    actor_t;
    constant request_id : in    message_id_t;
    constant payload    : in    string := "";
    constant timeout    : in    time   := max_timeout_c);
  procedure reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable message      : inout message_ptr_t;
    variable receipt      : out   receipt_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false);
  procedure reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false);
  procedure acknowledge (
    signal net            : inout network_t;
    constant sender       : in    actor_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    constant positive_ack : in    boolean := true;
    variable receipt      : out   receipt_t;
    constant timeout      : in    time    := max_timeout_c);
  procedure acknowledge (
    signal net            : inout network_t;
    constant sender       : in    actor_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    constant positive_ack : in    boolean := true;
    constant timeout      : in    time    := max_timeout_c);
  procedure acknowledge (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    constant positive_ack : in    boolean := true;
    variable receipt      : out   receipt_t;
    constant timeout      : in    time    := max_timeout_c);
  procedure acknowledge (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    constant positive_ack : in    boolean := true;
    constant timeout      : in    time    := max_timeout_c);
  procedure publish (
    signal net       : inout network_t;
    constant sender  : in    actor_t;
    constant payload : in    string := "";
    variable status  : out   com_status_t;
    constant timeout : in    time   := max_timeout_c);
  procedure publish (
    signal net       : inout network_t;
    constant sender  : in    actor_t;
    constant payload : in    string := "";
    constant timeout : in    time   := max_timeout_c);
  procedure publish (
    signal net            : inout network_t;
    variable message      : inout message_ptr_t;
    variable status       : out   com_status_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false);
  procedure publish (
    signal net            : inout network_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false);

  -----------------------------------------------------------------------------
  -- Receive related subprograms
  -----------------------------------------------------------------------------
  procedure wait_for_messages (
    signal net               : in  network_t;
    constant receiver        : in  actor_t;
    variable status          : out com_status_t;
    constant receive_timeout : in  time := max_timeout_c);
  impure function has_messages (actor   : actor_t) return boolean;
  impure function get_message (receiver : actor_t; delete_from_inbox : boolean := true) return message_ptr_t;
  procedure receive (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable message  : inout message_ptr_t;
    constant timeout  : in    time := max_timeout_c);
  procedure receive_reply (
    signal net          : inout network_t;
    constant receiver   : in    actor_t;
    constant request_id : in    message_id_t;
    variable message    : inout message_ptr_t;
    constant timeout    : in    time := max_timeout_c);
  procedure receive_reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    variable positive_ack : out   boolean;
    variable status       : out   com_status_t;
    constant timeout      : in    time := max_timeout_c);
  procedure receive_reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant request_id   : in    message_id_t;
    variable positive_ack : out   boolean;
    constant timeout      : in    time := max_timeout_c);
  procedure subscribe (
    constant subscriber : in  actor_t;
    constant publisher  : in  actor_t;
    variable status     : out com_status_t);
  procedure subscribe (subscriber : actor_t; publisher : actor_t);
  procedure unsubscribe (
    constant subscriber : in  actor_t;
    constant publisher  : in  actor_t;
    variable status     : out com_status_t);
  procedure unsubscribe (subscriber : actor_t; publisher : actor_t);  --
  impure function num_of_missed_messages (actor : actor_t) return natural;

  -----------------------------------------------------------------------------
  -- Message related subprograms
  -----------------------------------------------------------------------------
  impure function compose (
    payload : string := "";
    sender : actor_t := null_actor_c;
    request_id : message_id_t := no_message_id_c)
    return message_ptr_t;
  procedure delete (message : inout message_ptr_t);
end package;
