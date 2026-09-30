# {hello}: the same contract as a block in ~/.config/shkit/prompt.d (prompt-theme skill).
: ${SHKIT_COLOR_HELLO:='38;5;42'} ${SHKIT_ICON_HELLO=☺}   # its own defaults, overridable
function _prompt_seg_hello {
  _prompt_esc $USER   # every dynamic text is escaped
  segs+="${_c_hello}${_i_hello} ${REPLY}${_c_reset}"
}
