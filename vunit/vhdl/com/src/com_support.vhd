-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

context work.vunit_context;
use work.com_types_pkg.all;

package com_support_pkg is
  procedure check (expr : boolean; err : com_error_t; line_num : natural := 0; file_name : string := "");  --
  procedure check_failed (err : com_error_t; line_num : natural := 0; file_name : string := "");
  procedure deprecated (msg   : string);
end package com_support_pkg;

package body com_support_pkg is
  procedure check_failed (err : com_error_t; line_num : natural := 0; file_name : string := "") is
    constant err_msg             : string := replace(com_error_t'image(err), '_', ' ');
    alias err_msg_aligned        : string(1 to err_msg'length) is err_msg;
    constant err_msg_capitalized : string := upper(err_msg_aligned(1 to 1)) & err_msg_aligned(2 to err_msg'length);
  begin
    check_failed(err_msg_capitalized, level => failure, line_num => line_num, file_name => file_name);
  end;

  procedure check (expr : boolean; err : com_error_t; line_num : natural := 0; file_name : string := "") is
  begin
    if not expr then
      check_failed(err);
    end if;
  end;

  procedure deprecated (msg : string) is
  begin
    warning("DEPRECATED INTERFACE: " & msg);
  end;
end package body com_support_pkg;
