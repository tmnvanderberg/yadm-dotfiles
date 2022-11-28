# shellcheck shell=bash
# shellcheck disable=SC2034 # Expected behavior for themes.

function prompt_setter() {
	local clock_prompt 
	clock_prompt="$(clock_prompt)"
	_save-and-reload-history 1 # Save history
	PS1="(${clock_prompt}) [${yellow?}\w${reset_color?}] ${reset_color?} "
	PS2='> '
	PS4='+ '
}

safe_append_prompt_command prompt_setter

