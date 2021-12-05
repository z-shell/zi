# NAME

zi.zsh - a shell script

# SYNOPSIS

Documentation automatically generated with ‘zshelldoc’

# FUNCTIONS

     @autoload
     pmodload
     zi
     .zi-add-fpath
     .zi-add-report
     .zi-any-to-pid
     .zi-any-to-user-plugin
     zicdclear
     zicdreplay
     zicompdef
     .zi-compdef-clear
     .zi-compdef-replay
     zicompinit
     +zi-deploy-message
     .zi-diff
     .zi-diff-env
     .zi-diff-functions
     .zi-diff-options
     .zi-diff-parameter
     .zi-find-other-matches
     .zi-formatter-bar
     .zi-formatter-bar-util
     .zi-formatter-pid
     .zi-formatter-th-bar
     .zi-formatter-url
     .zi-get-mtime-into
     .zi-get-object-path
     .zi-ice
     .zi-load
     .zi-load-ices
     .zi-load-object
     .zi-load-plugin
     .zi-load-snippet
     .zi-main-message-formatter
     +zi-message
     zinit
     .zi-pack-ice
     .zi-parse-opts
     +zi-prehelp-usage-message
     .zi-prepare-home
     @zi-register-annex
     @zi-register-hook
     .zi-register-plugin
     :zi-reload-and-run
     .zi-run
     .zi-run-task
     -zi_scheduler_add_sh
     .zi-set-m-func
     .zi-setup-params
     .zi-submit-turbo
     @zi-substitute
     :zi-tmp-subst-alias
     :zi-tmp-subst-autoload
     :zi-tmp-subst-bindkey
     :zi-tmp-subst-compdef
     .zi-tmp-subst-off
     .zi-tmp-subst-on
     :zi-tmp-subst-zle
     :zi-tmp-subst-zstyle
     .zi-util-shands-path
     zpcdclear
     zpcdreplay
     zpcompdef
     zpcompinit
     @zsh-plugin-run-on-unload
     @zsh-plugin-run-on-update
     zt
    AUTOLOAD add-zsh-hook
    AUTOLOAD compinit
    AUTOLOAD is-at-least
    PRECMD-HOOK @zi-scheduler

# DETAILS

## Script Body

Has 203 line(s). Calls functions:

    Script-Body
    |-- add-zsh-hook
    |-- autoload.zsh/.zi-module
    |-- is-at-least
    |-- +zi-message
    `-- @zi-register-hook

Uses feature(s): *add-zsh-hook*, *alias*, *autoload*, *export*,
*is-at-least*, *setopt*, *source*, *zmodload*, *zstyle*

*Exports (environment):* PMSPEC **<span class="big">//</span>** ZPFX
**<span class="big">//</span>** ZSH_CACHE_DIR

## @autoload

>     ]]]
>     FUNCTION: @autoload. [[[

Has 3 line(s). Calls functions:

    @autoload
    `-- :zi-tmp-subst-autoload
        |-- is-at-least
        `-- +zi-message

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

## pmodload

>     FUNCTION: pmodload. [[[
>     Compatibility with Prezto. Calls can be recursive.

Has 15 line(s). Calls functions:

    pmodload

Uses feature(s): *zstyle*

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

## zi

>     FUNCTION: zi. [[[
>     Main function directly exposed to user, obtains subcommand and its arguments, has completion.

Has 548 line(s). Calls functions:

    zi
    |-- autoload.zsh/.zi-analytics-menu
    |-- autoload.zsh/.zi-cdisable
    |-- autoload.zsh/.zi-cenable
    |-- autoload.zsh/.zi-clear-completions
    |-- autoload.zsh/.zi-compiled
    |-- autoload.zsh/.zi-compile-uncompile-all
    |-- autoload.zsh/.zi-control-menu
    |-- autoload.zsh/.zi-help
    |-- autoload.zsh/.zi-list-bindkeys
    |-- autoload.zsh/.zi-list-compdef-replay
    |-- autoload.zsh/.zi-ls
    |-- autoload.zsh/.zi-module
    |-- autoload.zsh/.zi-recently
    |-- autoload.zsh/.zi-search-completions
    |-- autoload.zsh/.zi-self-update
    |-- autoload.zsh/.zi-show-all-reports
    |-- autoload.zsh/.zi-show-completions
    |-- autoload.zsh/.zi-show-debug-report
    |-- autoload.zsh/.zi-show-registered-plugins
    |-- autoload.zsh/.zi-show-report
    |-- autoload.zsh/.zi-show-times
    |-- autoload.zsh/.zi-show-zstatus
    |-- autoload.zsh/.zi-uncompile-plugin
    |-- autoload.zsh/.zi-uninstall-completions
    |-- autoload.zsh/.zi-unload
    |-- autoload.zsh/.zi-update-or-status
    |-- autoload.zsh/.zi-update-or-status-all
    |-- compinit
    |-- install.zsh/.zi-compile-plugin
    |-- install.zsh/.zi-compinit
    |-- install.zsh/.zi-forget-completion
    |-- install.zsh/.zi-install-completions
    |-- +zi-message
    `-- +zi-prehelp-usage-message
        `-- +zi-message

Uses feature(s): *autoload*, *compinit*, *eval*, *setopt*, *source*

Called by:

    zinit
    zt

<div class="formalpara-title">

**zi-add-fpath**

</div>

    ____

     FUNCTION: .zi-add-fpath. [[[
    ____

    Has 10 line(s). Calls functions:

     .zi-add-fpath

    Called by:

     zi

    .zi-add-report

>     FUNCTION: .zi-add-report. [[[
>     Adds a report line for given plugin.
>
>     $1 - uspl2, i.e. user/plugin
>     $2, ... - the text

Has 3 line(s). Doesn’t call other functions.

Called by:

    .zi-load-plugin
    .zi-load-snippet
    :zi-tmp-subst-alias
    :zi-tmp-subst-autoload
    :zi-tmp-subst-bindkey
    :zi-tmp-subst-compdef
    :zi-tmp-subst-zle
    :zi-tmp-subst-zstyle

<div class="formalpara-title">

**zi-any-to-pid**

</div>

    ____

     FUNCTION: .zi-any-to-pid. [[[
    ____

    Has 21 line(s). Calls functions:

     .zi-any-to-pid

    Uses feature(s): _setopt_

    Called by:

     side.zsh/.zi-any-colorify-as-uspl2
     side.zsh/.zi-exists-physically-message
     side.zsh/.zi-first

    .zi-any-to-user-plugin

>     FUNCTION: .zi-any-to-user-plugin. [[[
>     Allows elastic plugin-spec across the code.
>
>     $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
>     $2 - plugin (only when $1 - i.e. user - given)
>
>     Returns user and plugin in $reply.

Has 25 line(s). Doesn’t call other functions.

Uses feature(s): *setopt*

Called by:

    .zi-add-fpath
    .zi-get-object-path
    .zi-load
    .zi-run
    :zi-tmp-subst-autoload
    autoload.zsh/.zi-any-to-uspl2
    autoload.zsh/.zi-changes
    autoload.zsh/.zi-compiled
    autoload.zsh/.zi-compile-uncompile-all
    autoload.zsh/.zi-create
    autoload.zsh/.zi-delete
    autoload.zsh/.zi-find-completions-of-plugin
    autoload.zsh/.zi-glance
    autoload.zsh/.zi-show-report
    autoload.zsh/.zi-stress
    autoload.zsh/.zi-uncompile-plugin
    autoload.zsh/.zi-unload
    autoload.zsh/.zi-unregister-plugin
    autoload.zsh/.zi-update-all-parallel
    autoload.zsh/.zi-update-or-status-all
    autoload.zsh/.zi-update-or-status
    install.zsh/.zi-install-completions
    side.zsh/.zi-any-colorify-as-uspl2
    side.zsh/.zi-compute-ice
    side.zsh/.zi-exists-physically-message
    side.zsh/.zi-exists-physically
    side.zsh/.zi-first

*Environment variables used:* ZPFX

## zicdclear

>     ]]]
>     FUNCTION: zicdclear. [[[
>     A wrapper for `zi cdclear -q' which can be called from hook ices like the atinit'', atload'', etc. ices.

Has 1 line(s). Calls functions:

    zicdclear

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

## zicdreplay

>     FUNCTION: zicdreplay. [[[
>     A function that can be invoked from within `atinit', `atload', etc. ice-mod.
>     It works like `zi cdreplay', which cannot be invoked from such hook ices.

Has 1 line(s). Calls functions:

    zicdreplay

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

## zicompdef

>     ]]]
>     FUNCTION: zicompdef. [[[
>     Stores compdef for a replay with `zicdreplay' (turbo mode) or with `zi cdreplay' (normal mode). An utility functton of an undefined use case.

Has 1 line(s). Doesn’t call other functions.

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

<div class="formalpara-title">

**zi-compdef-clear**

</div>

    ____

     FUNCTION: .zi-compdef-clear. [[[
     Implements user-exposed functionality to clear gathered compdefs.
    ____

    Has 3 line(s). Calls functions:

     .zi-compdef-clear
     `-- +zi-message

    Called by:

     zicdclear
     zi
     zpcdclear

    .zi-compdef-replay

>     FUNCTION: .zi-compdef-replay. [[[
>     Runs gathered compdef calls. This allows to run `compinit' after loading plugins.

Has 16 line(s). Calls functions:

    .zi-compdef-replay
    `-- +zi-message

Uses feature(s): *compdef*

Called by:

    zicdreplay
    zi
    zpcdreplay

## zicompinit

>     ]]]
>     FUNCTION: zicompinit. [[[
>     A function that can be invoked from within `atinit', `atload', etc. ice-mod.
>     It runs `autoload compinit; compinit' and respects
>     ZI[ZCOMPDUMP_PATH] and ZI[COMPINIT_OPTS].

Has 1 line(s). Calls functions:

    zicompinit
    `-- compinit

Uses feature(s): *autoload*, *compinit*

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

## +zi-deploy-message

>     FUNCTION: +zi-deploy-message. [[[
>     Deploys a sub-prompt message to be displayed OR a `zle
>     .reset-prompt' call to be invoked

Has 13 line(s). Doesn’t call other functions.

Uses feature(s): *read*, *zle*

Called by:

    .zi-load-snippet
    .zi-load
    autoload.zsh/.zi-recall

<div class="formalpara-title">

**zi-diff**

</div>

    ____

     FUNCTION: .zi-diff. [[[
     Performs diff actions of all types
    ____

    Has 4 line(s). Calls functions:

     .zi-diff

    Called by:

     .zi-load-plugin

    .zi-diff-env

>     FUNCTION: .zi-diff-env. [[[
>     Implements detection of change in PATH and FPATH.
>
>     $1 - user/plugin (i.e. uspl2 format)
>     $2 - command, can be "begin" or "end"

Has 15 line(s). Doesn’t call other functions.

Called by:

    .zi-diff
    .zi-load-plugin

<div class="formalpara-title">

**zi-diff-functions**

</div>

    ____

     FUNCTION: .zi-diff-functions. [[[
     Implements detection of newly created functions. Performs data gathering, computation is done in *-compute().

     $1 - user/plugin (i.e. uspl2 format)
     $2 - command, can be "begin" or "end"
    ____

    Has 3 line(s). Doesn't call other functions.

    Called by:

     .zi-diff

    .zi-diff-options

>     FUNCTION: .zi-diff-options. [[[
>     Implements detection of change in option state. Performs
>     data gathering, computation is done in *-compute().
>
>     $1 - user/plugin (i.e. uspl2 format)
>     $2 - command, can be "begin" or "end"

Has 2 line(s). Doesn’t call other functions.

Called by:

    .zi-diff

<div class="formalpara-title">

**zi-diff-parameter**

</div>

    ____

     FUNCTION: .zi-diff-parameter. [[[
     Implements detection of change in any parameter's existence and type.
     Performs data gathering, computation is done in *-compute().

     $1 - user/plugin (i.e. uspl2 format)
     $2 - command, can be "begin" or "end"
    ____

    Has 7 line(s). Doesn't call other functions.

    Called by:

     .zi-diff

    .zi-find-other-matches

>     FUNCTION: .zi-find-other-matches. [[[
>     Plugin's main source file is in general `name.plugin.zsh'. However,
>     there can be different conventions, if that file is not found, then
>     this functions examines other conventions in the most sane order.

Has 17 line(s). Doesn’t call other functions.

Called by:

    .zi-load-plugin
    .zi-load-snippet
    side.zsh/.zi-first

<div class="formalpara-title">

**zi-formatter-bar**

</div>

    ____

     FUNCTION: .zi-formatter-bar. [[[
    ____

    Has 1 line(s). Calls functions:

     .zi-formatter-bar

    Not called by script or any function (may be e.g. a hook, a Zle widget, etc.).

    .zi-formatter-bar-util

>     FUNCTION: .zi-formatter-bar-util. [[[

Has 7 line(s). Doesn’t call other functions.

Called by:

    .zi-formatter-bar
    .zi-formatter-th-bar

<div class="formalpara-title">

**zi-formatter-pid**

</div>

    ____

     FUNCTION: .zi-formatter-pid. [[[
    ____

    Has 10 line(s). Calls functions:

     .zi-formatter-pid
     `-- side.zsh/.zi-any-colorify-as-uspl2

    Uses feature(s): _source_

    Not called by script or any function (may be e.g. a hook, a Zle widget, etc.).

    .zi-formatter-th-bar

>     FUNCTION: .zi-formatter-th-bar. [[[

Has 1 line(s). Calls functions:

    .zi-formatter-th-bar

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

<div class="formalpara-title">

**zi-formatter-url**

</div>

    ____

     FUNCTION: .zi-formatter-url. [[[
    ____

    Has 19 line(s). Doesn't call other functions.

    Not called by script or any function (may be e.g. a hook, a Zle widget, etc.).

    .zi-get-mtime-into

>     FUNCTION: .zi-get-mtime-into. [[[

Has 7 line(s). Doesn’t call other functions.

Called by:

    Script-Body
    autoload.zsh/.zi-self-update
    autoload.zsh/.zi-update-or-status-all

<div class="formalpara-title">

**zi-get-object-path**

</div>

    ____

     FUNCTION: .zi-get-object-path. [[[
    ____

    Has 22 line(s). Calls functions:

     .zi-get-object-path

    Called by:

     .zi-load-ices
     .zi-load-snippet
     .zi-run
     zi
     autoload.zsh/.zi-get-path
     install.zsh/.zi-setup-plugin-dir
     install.zsh/.zi-update-snippet
     side.zsh/.zi-first
     side.zsh/.zi-two-paths

    .zi-ice

>     FUNCTION: .zi-ice. [[[
>     Parses ICE specification, puts the result into ICE global hash. The ice-spec is valid for
>     next command only (i.e. it "melts"), but it can then stick to plugin and activate e.g. at update.

Has 11 line(s). Doesn’t call other functions.

Uses feature(s): *setopt*

Called by:

    zi

*Environment variables used:* ZPFX

<div class="formalpara-title">

**zi-load**

</div>

    ____

     FUNCTION: .zi-load. [[[
     Implements the exposed-to-user action of loading a plugin.

     $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
     $2 - plugin name, if the third format is used
    ____

    Has 76 line(s). Calls functions:

     .zi-load
     |-- install.zsh/.zi-get-package
     |-- install.zsh/.zi-setup-plugin-dir
     `-- +zi-deploy-message

    Uses feature(s): _eval_, _setopt_, _source_, _zle_

    Called by:

     .zi-load-object
     .zi-run-task

    .zi-load-ices

>     FUNCTION: .zi-load-ices. [[[

Has 22 line(s). Calls functions:

    .zi-load-ices

Called by:

    zi

*Environment variables used:* ZPFX

<div class="formalpara-title">

**zi-load-object**

</div>

    ____

     FUNCTION: .zi-load-object. [[[
    ____

    Has 10 line(s). Calls functions:

     .zi-load-object

    Called by:

     zi

    .zi-load-plugin

>     FUNCTION: .zi-load-plugin. [[[
>     Lower-level function for loading a plugin.
>
>     $1 - user
>     $2 - plugin
>     $3 - mode (light or load)

Has 107 line(s). Calls functions:

    .zi-load-plugin
    `-- :zi-tmp-subst-autoload
        |-- is-at-least
        `-- +zi-message

Uses feature(s): *eval*, *setopt*, *source*, *unfunction*, *zle*

Called by:

    .zi-load

<div class="formalpara-title">

**zi-load-snippet**

</div>

    ____

     FUNCTION: .zi-load-snippet. [[[
     Implements the exposed-to-user action of loading a snippet.

     $1 - url (can be local, absolute path).
    ____

    Has 173 line(s). Calls functions:

     .zi-load-snippet
     |-- install.zsh/.zi-download-snippet
     |-- +zi-deploy-message
     `-- +zi-message

    Uses feature(s): _autoload_, _eval_, _setopt_, _source_, _unfunction_, _zparseopts_, _zstyle_

    Called by:

     pmodload
     .zi-load-object
     .zi-load
     .zi-run-task

    .zi-main-message-formatter

>     FUNCTION: +zi-message-formatter [[[

Has 18 line(s). Doesn’t call other functions.

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

## +zi-message

>     FUNCTION: +zi-message. [[[

Has 14 line(s). Doesn’t call other functions.

Called by:

    Script-Body
    .zi-compdef-clear
    .zi-compdef-replay
    .zi-load-snippet
    +zi-prehelp-usage-message
    .zi-register-plugin
    .zi-run
    .zi-set-m-func
    :zi-tmp-subst-autoload
    zi
    autoload.zsh/.zi-build-module
    autoload.zsh/.zi-cd
    autoload.zsh/.zi-self-update
    autoload.zsh/.zi-show-zstatus
    autoload.zsh/.zi-uninstall-completions
    autoload.zsh/.zi-update-all-parallel
    autoload.zsh/.zi-update-or-status-all
    autoload.zsh/.zi-update-or-status
    autoload.zsh/.zi-wait-for-update-jobs
    install.zsh/.zi-compile-plugin
    install.zsh/.zi-compinit
    install.zsh/.zi-download-file-stdout
    install.zsh/.zi-download-snippet
    install.zsh/.zi-extract
    install.zsh/ziextract
    install.zsh/.zi-get-cygwin-package
    install.zsh/.zi-get-latest-gh-r-url-part
    install.zsh/.zi-get-package
    install.zsh/.zi-install-completions
    install.zsh/∞zi-ps-on-update-hook
    install.zsh/∞zi-reset-hook
    install.zsh/.zi-setup-plugin-dir
    install.zsh/.zi-update-snippet
    side.zsh/.zi-countdown
    side.zsh/.zi-exists-physically-message

## zinit

Has 1 line(s). Calls functions:

    zinit
    `-- zi
        |-- autoload.zsh/.zi-analytics-menu
        |-- autoload.zsh/.zi-cdisable
        |-- autoload.zsh/.zi-cenable
        |-- autoload.zsh/.zi-clear-completions
        |-- autoload.zsh/.zi-compiled
        |-- autoload.zsh/.zi-compile-uncompile-all
        |-- autoload.zsh/.zi-control-menu
        |-- autoload.zsh/.zi-help
        |-- autoload.zsh/.zi-list-bindkeys
        |-- autoload.zsh/.zi-list-compdef-replay
        |-- autoload.zsh/.zi-ls
        |-- autoload.zsh/.zi-module
        |-- autoload.zsh/.zi-recently
        |-- autoload.zsh/.zi-search-completions
        |-- autoload.zsh/.zi-self-update
        |-- autoload.zsh/.zi-show-all-reports
        |-- autoload.zsh/.zi-show-completions
        |-- autoload.zsh/.zi-show-debug-report
        |-- autoload.zsh/.zi-show-registered-plugins
        |-- autoload.zsh/.zi-show-report
        |-- autoload.zsh/.zi-show-times
        |-- autoload.zsh/.zi-show-zstatus
        |-- autoload.zsh/.zi-uncompile-plugin
        |-- autoload.zsh/.zi-uninstall-completions
        |-- autoload.zsh/.zi-unload
        |-- autoload.zsh/.zi-update-or-status
        |-- autoload.zsh/.zi-update-or-status-all
        |-- compinit
        |-- install.zsh/.zi-compile-plugin
        |-- install.zsh/.zi-compinit
        |-- install.zsh/.zi-forget-completion
        |-- install.zsh/.zi-install-completions
        |-- +zi-message
        `-- +zi-prehelp-usage-message
            `-- +zi-message

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

<div class="formalpara-title">

**zi-pack-ice**

</div>

    ____

     FUNCTION: .zi-pack-ice. [[[
     Remembers all ice-mods, assigns them to concrete plugin. Ice spec is in general forgotten for
     second-next command (that's why it's called "ice" - it melts), however they glue to the object (plugin
     or snippet) mentioned in the next command – for later use with e.g. `zi update ...'.
    ____

    Has 3 line(s). Doesn't call other functions.

    Called by:

     .zi-load-snippet
     .zi-load
     @zsh-plugin-run-on-unload
     @zsh-plugin-run-on-update
     install.zsh/.zi-update-snippet
     side.zsh/.zi-compute-ice

    .zi-parse-opts

>     FUNCTION: +zi-parse-opts. [[[

Has 2 line(s). Doesn’t call other functions.

Called by:

    zi
    autoload.zsh/.zi-delete

## +zi-prehelp-usage-message

>     FUNCTION: +zi-prehelp-usage-message. [[[

Has 38 line(s). Calls functions:

    +zi-prehelp-usage-message
    `-- +zi-message

Called by:

    zi
    autoload.zsh/.zi-delete

<div class="formalpara-title">

**zi-prepare-home**

</div>

    ____

     FUNCTION: .zi-prepare-home. [[[
     Creates all directories needed by ZI, first checks if they already exist.
    ____

    Has 38 line(s). Calls functions:

     .zi-prepare-home
     |-- autoload.zsh/.zi-clear-completions
     `-- install.zsh/.zi-compinit

    Uses feature(s): _source_

    Called by:

     Script-Body

    _Environment variables used:_ ZPFX

    @zi-register-annex

>     FUNCTION: @zi-register-annex. [[[
>     Registers the z-annex inside ZI – i.e. an ZI extension

Has 8 line(s). Doesn’t call other functions.

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

## @zi-register-hook

>     FUNCTION: @zi-register-hook. [[[
>     Registers the z-annex inside ZI – i.e. an ZI extension

Has 4 line(s). Doesn’t call other functions.

Called by:

    Script-Body

<div class="formalpara-title">

**zi-register-plugin**

</div>

    ____

     FUNCTION: .zi-register-plugin. [[[
     Adds the plugin to ZI_REGISTERED_PLUGINS array and to the
     zsh_loaded_plugins array (managed according to the plugin standard:
     http://z-shell.github.io/ZSH-TOP-100/Zsh-Plugin-Standard.html).
    ____

    Has 20 line(s). Calls functions:

     .zi-register-plugin
     `-- +zi-message

    Called by:

     .zi-load

    :zi-reload-and-run

>     FUNCTION: :zi-reload-and-run. [[[
>     Marks given function ($3) for autoloading, and executes it triggering the load.
>     $1 is the fpath dedicated  to the function, $2 are autoload options. This function replaces "autoload -X",
>     because using that on older Zsh versions causes problems with traps.
>
>     So basically one creates function stub that calls :zi-reload-and-run() instead of "autoload -X".
>
>     $1 - FPATH dedicated to function
>     $2 - autoload options
>     $3 - function name (one that needs autoloading)
>
>     Author: Bart Schaefer

Has 9 line(s). Doesn’t call other functions.

Uses feature(s): *autoload*, *unfunction*

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

<div class="formalpara-title">

**zi-run**

</div>

    ____

     FUNCTION: .zi-run. [[[
     Run code inside plugin's folder
     It uses the `correct' parameter from upper's scope zi().
    ____

    Has 24 line(s). Calls functions:

     .zi-run
     `-- +zi-message

    Uses feature(s): _eval_, _setopt_

    Called by:

     zi

    .zi-run-task

>     FUNCTION: .zi-run-task. [[[
>     A backend, worker function of .zi-scheduler. It obtains the tasks
>     index and a few of its properties (like the type: plugin, snippet,
>     service plugin, service snippet) and executes it first checking for
>     additional conditions (like non-numeric wait'' ice).
>
>     $1 - the pass number, either 1st or 2nd pass
>     $2 - the time assigned to the task
>     $3 - type: plugin, snippet, service plugin, service snippet
>     $4 - task's index in the ZI[WAIT_ICE_...] fields
>     $5 - mode: load or light
>     $6 - the plugin-spec or snippet URL or alias name (from id-as'')

Has 45 line(s). Calls functions:

    .zi-run-task
    `-- autoload.zsh/.zi-unload

Uses feature(s): *eval*, *source*, *zle*, *zpty*

Called by:

    @zi-scheduler

## @zi-scheduler

>     FUNCTION: @zi-scheduler. [[[
>     Searches for timeout tasks, executes them. There's an array of tasks
>     waiting for execution, this scheduler manages them, detects which ones
>     should be run at current moment, decides to remove (or not) them from
>     the array after execution.
>
>     $1 - if "following", then it is non-first (second and more)
>     invocation of the scheduler; this results in chain of `sched'
>     invocations that results in repetitive @zi-scheduler activity.
>
>     if "burst", then all tasks are marked timeout and executed one
>     by one; this is handy if e.g. a docker image starts up and
>     needs to install all turbo-mode plugins without any hesitation
>     (delay), i.e. "burst" allows to run package installations from
>     script, not from prompt.

Has 74 line(s). **Is a precmd hook**. Calls functions:

    @zi-scheduler
    `-- add-zsh-hook

Uses feature(s): *add-zsh-hook*, *sched*, *setopt*, *zle*

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

## -zi_scheduler_add_sh

>     FUNCTION: -zi_scheduler_add_sh. [[[
>     Copies task into ZI_RUN array, called when a task timeouts.
>     A small function ran from pattern in /-substitution as a math
>     function.

Has 7 line(s). Doesn’t call other functions.

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

<div class="formalpara-title">

**zi-set-m-func**

</div>

    ____

     FUNCTION:.zi-set-m-func() [[[
     Sets and withdraws the temporary, atclone/atpull time function `m`.
    ____

    Has 17 line(s). Calls functions:

     .zi-set-m-func
     `-- +zi-message

    Uses feature(s): _setopt_

    Called by:

     .zi-load-snippet
     .zi-load
     autoload.zsh/.zi-update-or-status

    .zi-setup-params

>     ]]]
>     FUNCTION: .zi-setup-params. [[[

Has 3 line(s). Doesn’t call other functions.

Called by:

    .zi-load-snippet
    .zi-load

<div class="formalpara-title">

**zi-submit-turbo**

</div>

    ____

     FUNCTION: .zi-submit-turbo. [[[
     If `zi load`, `zi light` or `zi snippet`  will be
     preceded with `wait', `load', `unload' or `on-update-of`/`subscribe'
     ice-mods then the plugin or snipped is to be loaded in turbo-mode,
     and this function adds it to internal data structures, so that
     @zi-scheduler can run (load, unload) this as a task.
    ____

    Has 16 line(s). Doesn't call other functions.

    Called by:

     zi

    @zi-substitute

>     FUNCTION: @zi-substitute. [[[

Has 36 line(s). Doesn’t call other functions.

Uses feature(s): *setopt*

Called by:

    autoload.zsh/.zi-at-eval
    install.zsh/∞zi-atclone-hook
    install.zsh/.zi-at-eval
    install.zsh/∞zi-cp-hook
    install.zsh/∞zi-extract-hook
    install.zsh/.zi-get-package
    install.zsh/∞zi-make-ee-hook
    install.zsh/∞zi-make-e-hook
    install.zsh/∞zi-make-hook
    install.zsh/∞zi-mv-hook

*Environment variables used:* ZPFX

## :zi-tmp-subst-alias

>     FUNCTION: :zi-tmp-subst-alias. [[[
>     Function defined to hijack plugin's calls to the `alias' builtin.
>
>     The hijacking is to gather report data (which is used in unload).

Has 30 line(s). Calls functions:

    :zi-tmp-subst-alias

Uses feature(s): *alias*, *setopt*, *zparseopts*

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

## :zi-tmp-subst-autoload

>     FUNCTION: :zi-tmp-subst-autoload. [[[
>     Function defined to hijack plugin's calls to the `autoload' builtin.
>
>     The hijacking is not only to gather report data, but also to.
>     run custom `autoload' function, that doesn't need FPATH.

Has 106 line(s). Calls functions:

    :zi-tmp-subst-autoload
    |-- is-at-least
    `-- +zi-message

Uses feature(s): *autoload*, *eval*, *is-at-least*, *setopt*,
*zparseopts*

Called by:

    @autoload
    .zi-load-plugin

## :zi-tmp-subst-bindkey

>     FUNCTION: :zi-tmp-subst-bindkey. [[[
>     Function defined to hijack plugin's calls to the `bindkey' builtin.
>
>     The hijacking is to gather report data (which is used in unload).

Has 107 line(s). Calls functions:

    :zi-tmp-subst-bindkey
    `-- is-at-least

Uses feature(s): *bindkey*, *is-at-least*, *setopt*, *zparseopts*

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

## :zi-tmp-subst-compdef

>     FUNCTION: :zi-tmp-subst-compdef. [[[
>     Function defined to hijack plugin's calls to the `compdef' function.
>     The hijacking is not only for reporting, but also to save compdef
>     calls so that `compinit' can be called after loading plugins.

Has 5 line(s). Calls functions:

    :zi-tmp-subst-compdef

Uses feature(s): *setopt*

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

<div class="formalpara-title">

**zi-tmp-subst-off**

</div>

    ____

     FUNCTION: .zi-tmp-subst-off. [[[
     Turn off temporary substituting of functions completely for a given mode ("load", "light",
     "light-b" (i.e. the `trackbinds' mode) or "compdef").
    ____

    Has 17 line(s). Doesn't call other functions.

    Uses feature(s): _setopt_, _unfunction_

    Called by:

     .zi-load-plugin

    .zi-tmp-subst-on

>     FUNCTION: .zi-tmp-subst-on. [[[
>     Turn on temporary substituting of functions of builtins and functions according to passed
>     mode ("load", "light", "light-b" or "compdef"). The temporary substituting of functions is
>     to gather report data, and to hijack `autoload', `bindkey' and `compdef' calls.

Has 29 line(s). Doesn’t call other functions.

Uses feature(s): *source*

Called by:

    .zi-load-plugin

## :zi-tmp-subst-zle

>     FUNCTION: :zi-tmp-subst-zle. [[[.
>     Function defined to hijack plugin's calls to the `zle' builtin.
>
>     The hijacking is to gather report data (which is used in unload).

Has 33 line(s). Calls functions:

    :zi-tmp-subst-zle

Uses feature(s): *setopt*, *zle*

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

## :zi-tmp-subst-zstyle

>     FUNCTION: :zi-tmp-subst-zstyle. [[[
>     Function defined to hijack plugin's calls to the `zstyle' builtin.
>
>     The hijacking is to gather report data (which is used in unload).

Has 19 line(s). Calls functions:

    :zi-tmp-subst-zstyle

Uses feature(s): *setopt*, *zparseopts*, *zstyle*

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

<div class="formalpara-title">

**zi-util-shands-path**

</div>

    ____

     FUNCTION: .zi-util-shands-path. [[[
     Replaces parts of path with %HOME, etc.
    ____

    Has 8 line(s). Doesn't call other functions.

    Uses feature(s): _setopt_

    Called by:

     .zi-any-to-pid

    _Environment variables used:_ ZPFX

    zpcdclear

Has 1 line(s). Calls functions:

    zpcdclear

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

## zpcdreplay

Has 1 line(s). Calls functions:

    zpcdreplay

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

## zpcompdef

Has 1 line(s). Doesn’t call other functions.

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

## zpcompinit

Has 1 line(s). Calls functions:

    zpcompinit
    `-- compinit

Uses feature(s): *autoload*, *compinit*

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

## @zsh-plugin-run-on-unload

>     FUNCTION: @zsh-plugin-run-on-update. [[[
>     The Plugin Standard required mechanism, see:
>     http://z-shell.github.io/ZSH-TOP-100/Zsh-Plugin-Standard.html

Has 2 line(s). Calls functions:

    @zsh-plugin-run-on-unload

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

## @zsh-plugin-run-on-update

>     FUNCTION: @zsh-plugin-run-on-update. [[[
>     The Plugin Standard required mechanism

Has 2 line(s). Calls functions:

    @zsh-plugin-run-on-update

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

## zt

>     Compatibility functions. [[[

Has 1 line(s). Calls functions:

    zt
    `-- zi
        |-- autoload.zsh/.zi-analytics-menu
        |-- autoload.zsh/.zi-cdisable
        |-- autoload.zsh/.zi-cenable
        |-- autoload.zsh/.zi-clear-completions
        |-- autoload.zsh/.zi-compiled
        |-- autoload.zsh/.zi-compile-uncompile-all
        |-- autoload.zsh/.zi-control-menu
        |-- autoload.zsh/.zi-help
        |-- autoload.zsh/.zi-list-bindkeys
        |-- autoload.zsh/.zi-list-compdef-replay
        |-- autoload.zsh/.zi-ls
        |-- autoload.zsh/.zi-module
        |-- autoload.zsh/.zi-recently
        |-- autoload.zsh/.zi-search-completions
        |-- autoload.zsh/.zi-self-update
        |-- autoload.zsh/.zi-show-all-reports
        |-- autoload.zsh/.zi-show-completions
        |-- autoload.zsh/.zi-show-debug-report
        |-- autoload.zsh/.zi-show-registered-plugins
        |-- autoload.zsh/.zi-show-report
        |-- autoload.zsh/.zi-show-times
        |-- autoload.zsh/.zi-show-zstatus
        |-- autoload.zsh/.zi-uncompile-plugin
        |-- autoload.zsh/.zi-uninstall-completions
        |-- autoload.zsh/.zi-unload
        |-- autoload.zsh/.zi-update-or-status
        |-- autoload.zsh/.zi-update-or-status-all
        |-- compinit
        |-- install.zsh/.zi-compile-plugin
        |-- install.zsh/.zi-compinit
        |-- install.zsh/.zi-forget-completion
        |-- install.zsh/.zi-install-completions
        |-- +zi-message
        `-- +zi-prehelp-usage-message
            `-- +zi-message

Not called by script or any function (may be e.g. a hook, a Zle widget,
etc.).

## add-zsh-hook

>     Add to HOOK the given FUNCTION.
>     HOOK is one of chpwd, precmd, preexec, periodic, zshaddhistory,
>     zshexit, zsh_directory_name (the _functions subscript is not required).
>
>     With -d, remove the function from the hook instead; delete the hook
>     variable if it is empty.
>
>     -D behaves like -d, but pattern characters are active in the
>     function name, so any matching function will be deleted from the hook.

Has 93 line(s). Doesn’t call other functions.

Uses feature(s): *autoload*, *getopts*

Called by:

    Script-Body
    @zi-scheduler

## compinit

>     Initialisation for new style completion. This mainly contains some helper
>     functions and setup. Everything else is split into different files that
>     will automatically be made autoloaded (see the end of this file).  The
>     names of the files that will be considered for autoloading are those that
>     begin with an underscores (like `_condition).
>
>     The first line of each of these files is read and must indicate what
>     should be done with its contents:
>
>     `#compdef <names ...>'

Has 549 line(s). Doesn’t call other functions.

Uses feature(s): *autoload*, *bindkey*, *compdef*, *compdump*, *eval*,
*read*, *setopt*, *unfunction*, *zle*, *zstyle*

Called by:

    zi
    zicompinit
    zpcompinit

## is-at-least

>     Test whether $ZSH_VERSION (or some value of your choice, if a second argument
>     is provided) is greater than or equal to x.y.z-r (in argument one). In fact,
>     it'll accept any dot/dash-separated string of numbers as its second argument
>     and compare it to the dot/dash-separated first argument. Leading non-number
>     parts of a segment (such as the "zefram" in 3.1.2-zefram4) are not considered
>     when the comparison is done; only the numbers matter. Any left-out segments
>     in the first argument that are present in the version string compared are
>     considered as zeroes, eg 3 == 3.0 == 3.0.0 == 3.0.0.0 and so on.

Has 56 line(s). Doesn’t call other functions.

Called by:

    Script-Body
    :zi-tmp-subst-autoload
    :zi-tmp-subst-bindkey
