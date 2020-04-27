#!/bin/bash

BASE="$(git rev-parse --show-toplevel)"

# colors for output messages
r="\x1B[31m" # red
y="\x1B[33m" # yellow
g="\x1B[32m" # green
d="\x1B[39m" # default
b="\x1B[1m" # bold
u="\x1B[0m" # unbold
cc="$d" # current color

# generic/helper functions
function generic_interactive {
    read -r answer
    if [ "$answer" = "y" ] || [ "$answer" = "yes" ]; then
        echo -e "\t... above hook is going to be $b$3$u.\n"
        echo "$1 $2"
        $1 "$2"
    fi
}

function generic_toggle {
    if [ $# -eq 2 ]; then
        if [ "$2" = "--all" ]; then
            for hook in githooks/*; do
                $1 "$hook" "$(cut -d '.' -f1 "$hook")"
            done
        else
            $1 "$2" "$(cut -d '.' -f1 "$2")"
        fi
    else
        command="$1"
        shift
        for hook in $@; do
                $command "$hook" "$(cut -d '.' -f1 "$hook")"
        done
    fi
}

function helper_enable {
    # ensure that passed gook holds actual extension:
    # a simple check whether a dot is in hook name should be sufficient,
    # because naming of all files within githooks/ must match list of git hooks.
    hook=""
    if [[ $1 == *"."* ]]; then
        hook="$1"
    else 
        hook_absolute_path="$(find "$BASE/test" -name "$1.*")"
        hook=${hook_absolute_path##*/}
    fi

    ln -s "$BASE/githooks/$hook" "$BASE/.git/hooks/$2"
    echo -e "\t$2 hook ${g}enabled${d}"
}

function helper_disable {
    rm "$BASE/.git/hooks/$2"
    echo -e "\t$2 hook ${y}disabled${d}"
}

## actual commands/task which can be invoked
function disable {
    generic_toggle "helper_disable" $@
}

function enable {
    generic_toggle "helper_enable" $@
}

function interactive { # argumentless function
    echo -e "\n$b[INFO]$u each ${b}hook$u will be listed with its ${b}status$u. Say yes or no to change hook state. (y/${b}N$u)\n"

    # looping over hook in ./githooks/
    for hook in "$BASE"/githooks/*; do
        hook_without_extension="$(cut -d '.' -f1 "$hook")"

        if [ -f "$BASE/.git/hooks/$hook_without_extension" ]; then
            echo -e "\t${g}$hook_without_extension hook is enabled${d}. Do you want to ${b}disable$u it? (y/N)"
            generic_interactive disable "$hook" "enabled"
        else
            echo -e "\t${y}$hook_without_extension hook is disabled${d}. Do you want to ${b}enable$u it? (y/N)"
            generic_interactive enable "$hook" "disabled"
        fi 
    done

    # searching for orphaned hooks in ./.git/hooks
    for hook in "$BASE"/.git/hooks/*; do
        # early return if file is sample file
        if [[ "$hook" == *".sample" ]]; then
            continue
        fi

        acutal_hook="$(find "$BASE"/githooks -name "$(basename $hook).*")"
        
        if [ -z $acutal_hook ] || [ ! -f $acutal_hook ]; then
            echo -e "\t${r}$(basename $hook) hook is orphaned.$u Do you want to ${b}delete$u it? (y/N)${d}"
            generic_interactive disable "$hook" "deleted"
        fi
    done
}

function list { # argumentless function
    echo -e "\n${b}[INFO]${u} listing all hooks ${b}(${g}enabled${d}/${y}disabled${d}/${r}orphaned${d})${u}"
    # looping over hooks in ./githooks/
    for hook_absolute_path in "$BASE"/githooks/*; do
        
        hook="${hook_absolute_path##*/}"
        hook_without_extension="$(echo "$hook" | cut -d '.' -f1)"

        if [ -f "$BASE/.git/hooks/$hook_without_extension" ]; then
            cc="$g"
        else
            cc="$y"
        fi
        echo -e "\t${b}${cc}$hook_without_extension${d}${u}"
    done

    # searching for orphaned hooks in ./.git/hooks
    for file in "$BASE"/.git/hooks/*; do
        # early return if file is sample file
        if [[ $file == *".sample" ]]; then
            continue
        fi

        # TODO: remove ${file##*/} with "basename" command for readability
        path_of_linked_script_by_hook=$(find "$BASE"/githooks -name "${file##*/}.*")

        if [ -z "$path_of_linked_script_by_hook" ] || [ ! -f "$path_of_linked_script_by_hook" ]; then
            echo -e "\t${r}${file##*/}${d}"
        fi
    done
}

# short-hand commands
function d {
    delete $@
}
function e {
    enable $@
}
function i {
    interactive
}
function l {
    list
}

# evaluating passed args 
command=$1; shift
$command $@