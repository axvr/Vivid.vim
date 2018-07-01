" ==============================================================================
" Name:         Vivid.vim
" Author:       Alex Vear
" HomePage:     https://github.com/axvr/Vivid.vim
" Licence:      MIT Licence
" ==============================================================================

" Prevent Vivid being loaded multiple times (and users can check if enabled)
if exists('g:loaded_vivid') || !has('packages') || &cp | finish | endif
let g:loaded_vivid = 1 | lockvar g:loaded_vivid

let s:plugins = {}
let s:plugin_defaults = { 'enabled': 0, 'depth': 1, 'name': '' }
lockvar s:plugin_defaults

" Find Vivid install location (fast if nothing has been added to the 'rtp' yet)
for s:path in split(&runtimepath, ',')
    if s:path =~# '.Vivid\.vim$'
        let g:vlf_install_location = substitute(s:path, '\m\C.Vivid\.vim$', '', '')
        lockvar g:vlf_install_location
        unlet s:path
        break
    endif
endfor

" Completion for Vivid commands
function! vivid#complete(...)
    return sort(filter(keys(s:plugins), 'stridx(v:val, a:1) == 0'))
endfunction

" Generate helptags
function! s:gen_helptags(doc_location) abort
    if isdirectory(a:doc_location)
        execute 'helptags ' . expand(a:doc_location)
    endif
endfunction

" Add a plugin for Vivid to manage
function! vivid#add(remote, ...) abort

    " Create dictionary to be added to s:plugins
    let l:new_plugin = copy(s:plugin_defaults)
    if !empty(a:000) && type(a:1) == v:t_dict
        call extend(l:new_plugin, a:1, 'force')
    endif

    " Create the remote address, if the shortened variant was provided
    if a:remote =~# '\m\C^[-A-Za-z0-9]\+\/[-._A-Za-z0-9]\+$'
        let l:new_plugin['remote'] = 'https://git::@github.com/' . a:remote
    elseif empty(a:remote)
        throw 'No remote address given'
    else
        let l:new_plugin['remote'] = a:remote
    endif

    " Generate a name if none was given
    let l:name = l:new_plugin['name']
    if l:name ==# ''
        let l:name = split(l:new_plugin['remote'], '/')
        let l:name = substitute(l:name[-1], '\m\C\.git$', '', '')
    endif

    if has_key(l:new_plugin, 'command')
        for l:cmd in l:new_plugin['command']
            execute 'command '.l:cmd.' :call vivid#enable("'.l:name.'") | silent! '.l:cmd
        endfor
    endif

    " Add the new plugin to the plugins dictionary
    if !has_key(s:plugins, l:name)
        let s:plugins[l:name] = l:new_plugin
    endif

    " Enable plugin (if auto-enable was selected)
    if l:new_plugin['enabled'] == 1
        let s:plugins[l:name]['enabled'] = 0
        call vivid#enable(l:name)
    endif

endfunction

" Allows the user to check if a plugin is enabled or not
" Returns:  1 == enabled, 0 == disabled or not managed by Vivid
function! vivid#enabled(plugin_name) abort
    return get(s:plugins, a:plugin_name, 0)['enabled']
endfunction

" Usage: let l:var = <SID>pick_a_dictionary(a:000)
function! s:pick_a_dictionary(...) abort
    if empty(a:000) || a:000 == [[]]
        return 's:plugins'
    elseif !empty(a:000) && type(a:1) == v:t_list
        let s:manipulate = {}
        for l:item in a:1
            if has_key(s:plugins, l:item) && !has_key(s:manipulate, l:item)
                let s:manipulate[l:item] = s:plugins[l:item]
            endif
        endfor
        return 's:manipulate'
    endif
endfunction

" Install plugins
function! vivid#install(...) abort
    let l:dict = <SID>pick_a_dictionary(a:000)
    for [l:plugin, l:data] in items({l:dict})
        let l:echo_message = 'Vivid: Plugin install -'
        let l:install_path = expand(g:vlf_install_location . '/' . l:plugin)
        if !isdirectory(l:install_path)
            let l:cmd = 'git clone --recurse-submodules "' .
                        \ l:data['remote'] . '" "' . l:install_path . '"'
            if system(l:cmd) =~# '\m\C\(warning\|fatal\):'
                echohl ErrorMsg
                echomsg l:echo_message 'Failed:   ' l:plugin
                echohl None
            else
                echomsg l:echo_message 'Installed:' l:plugin
            endif
        endif
    endfor
endfunction

" Update plugins
function! vivid#update(...) abort
    let l:dict = <SID>pick_a_dictionary(a:000)
    for l:plugin in keys({l:dict})
        let l:echo_message = 'Vivid: Plugin update  -'
        let l:plugin_location = expand(g:vlf_install_location . '/' . l:plugin)
        let l:cmd = 'git -C "' . l:plugin_location .
                    \ '" pull --recurse-submodules'
        let l:output = system(l:cmd)

        if !isdirectory(l:plugin_location)
            echomsg l:echo_message     'Skipped:  ' l:plugin
        elseif l:output =~# '\m\CAlready up[- ]to[- ]date\.'
            echomsg l:echo_message     'Latest:   ' l:plugin
        elseif l:output =~# '\m\C^\(From\|Updating\)'
            echomsg l:echo_message 'Updated:  ' l:plugin
        else
            echohl ErrorMsg
            echomsg l:echo_message 'Failed:   ' l:plugin
            echohl None
        endif
    endfor
endfunction

" Enable plugins
function! vivid#enable(...) abort
    let l:dict = <SID>pick_a_dictionary(a:000)
    for l:plugin in keys({l:dict})
        if s:plugins[l:plugin]['enabled'] == 0
            if !isdirectory(g:vlf_install_location . '/' . l:plugin)
                call vivid#install(l:plugin)
            endif
            let s:plugins[l:plugin]['enabled'] = 1
            silent execute 'packadd ' . l:plugin
            let l:doc = expand(g:vlf_install_location . '/' . l:plugin . '/doc/')
            call <SID>gen_helptags(l:doc)
        endif
    endfor
endfunction

" Create a list of all dirs to delete
function! s:list_all_files(...) abort
    " TODO create and use a comma separated list of paths
    let l:dir_list = globpath(g:vlf_install_location, '*', 0, 1)
    for l:dir in l:dir_list
        let l:name = split(l:dir, '/')
        let l:name = substitute(l:name[-1], '\m\C\.git$', '', '')
        if has_key(s:plugins, l:name)
            call remove(l:dir_list, index(l:dir_list, l:dir))
        endif
    endfor
    return l:dir_list
endfunction

" Clean unused plugins
" TODO improve the plugin cleaning system
function! vivid#clean(...) abort
    if empty(a:000) || a:000 == [[]]
        for l:file in <SID>list_all_files()
            call delete(expand(l:file), 'rf')
            echomsg 'Vivid: Plugin clean   - Deleted:  ' l:file
        endfor
    else
        let l:dict = <SID>pick_a_dictionary(a:000)
        for l:plugin in keys({l:dict})
            let s:plugins[l:plugin]['enabled'] = 0
            call delete(expand(g:vlf_install_location . '/' . l:plugin), 'rf')
            echomsg 'Vivid: Plugin clean   - Deleted:  ' l:plugin
        endfor
    endif
endfunction

call vivid#add('axvr/Vivid.vim', { 'enabled': 1 })
" vim: set et ts=4 sts=4 sw=4 tw=80 ft=vim ff=unix fenc=utf-8 :
