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

  procedure destroy (actor : inout actor_t);
  procedure reset_messenger;

  impure function num_of_actors return natural;
  impure function num_of_deferred_creations return natural;
  impure function inbox_size (actor : actor_t) return natural;

  -----------------------------------------------------------------------------
  -- Message related subprograms
  -----------------------------------------------------------------------------
  impure function new_message (sender : actor_t := null_actor_c) return message_ptr_t;
  impure function compose (
    payload : string := "";
    sender : actor_t := null_actor_c;
    request_id : message_id_t := no_message_id_c)
    return message_ptr_t;
  procedure copy (src : inout message_ptr_t; dst : inout message_ptr_t);
  procedure delete (message : inout message_ptr_t);

  -----------------------------------------------------------------------------
  -- Receive related subprograms
  -----------------------------------------------------------------------------
  procedure wait_for_message (
    signal net               : in  network_t;
    constant receiver        : in  actor_t;
    variable status          : out com_status_t;
    constant timeout : in  time := max_timeout_c);
  procedure wait_for_reply (
    signal net               : inout network_t;
    variable request  : inout message_ptr_t;
    variable status          : out   com_status_t;
    constant timeout : in    time := max_timeout_c);
  procedure wait_for_reply (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    constant receipt  : in receipt_t;
    variable status          : out   com_status_t;
    constant timeout : in    time := max_timeout_c);
  impure function has_message (actor   : actor_t) return boolean;
  impure function get_message (receiver : actor_t; delete_from_inbox : boolean := true) return message_ptr_t;
  impure function get_reply (
    receiver : actor_t;
    receipt : receipt_t;
    delete_from_inbox : boolean := true)
    return message_ptr_t;
  procedure get_reply (
    variable request           : inout message_ptr_t;
    variable reply             : inout message_ptr_t;
    constant delete_from_inbox : in    boolean := true);
  procedure receive (
    signal net        : inout network_t;
    constant receiver : in    actor_t;
    variable message  : inout message_ptr_t;
    constant timeout  : in    time := max_timeout_c);
  procedure receive_reply (
    signal net          : inout network_t;
    constant receiver   : in    actor_t;
    constant receipt    : in    receipt_t;
    variable message    : inout message_ptr_t;
    constant timeout    : in    time := max_timeout_c);
  procedure receive_reply (
    signal net          : inout network_t;
    variable request    : inout    message_ptr_t;
    variable message    : inout message_ptr_t;
    constant timeout    : in    time := max_timeout_c);
  procedure receive_reply (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    constant receipt    : in    receipt_t;
    variable positive_ack : out   boolean;
    constant timeout      : in    time := max_timeout_c);
  procedure receive_reply (
    signal net            : inout network_t;
    variable request    : inout    message_ptr_t;
    variable positive_ack : out   boolean;
    constant timeout      : in    time := max_timeout_c);

  -----------------------------------------------------------------------------
  -- Subscriptions
  -----------------------------------------------------------------------------
  procedure subscribe (subscriber : actor_t; publisher : actor_t);
  procedure unsubscribe (subscriber : actor_t; publisher : actor_t);

  -----------------------------------------------------------------------------
  -- Send related subprograms
  -----------------------------------------------------------------------------
  procedure send (
    signal net            : inout network_t;
    constant receiver     : in    actor_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := true);
  procedure request (
    signal net               : inout network_t;
    constant receiver        : in    actor_t;
    variable request_message : inout message_ptr_t;
    variable reply_message   : inout message_ptr_t;
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
    signal net            : inout network_t;
    variable request   : inout    message_ptr_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false);
  procedure publish (
    signal net            : inout network_t;
    variable message      : inout message_ptr_t;
    constant timeout      : in    time    := max_timeout_c;
    constant keep_message : in    boolean := false);
  procedure acknowledge (
    signal net            : inout network_t;
    variable request   : inout    message_ptr_t;
    constant positive_ack : in    boolean := true;
    constant timeout      : in    time    := max_timeout_c);

  -----------------------------------------------------------------------------
  -- Misc
  -----------------------------------------------------------------------------

  procedure allow_timeout;
  procedure allow_deprecated;
  procedure deprecated (msg : string);


end package;
