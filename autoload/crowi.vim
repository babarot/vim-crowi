" A simple plugin for Crowi
" URL: http://site.crowi.wiki/

let g:crowi#api_url = get(g:, 'crowi#api_url', '')
let g:crowi#access_token = get(g:, 'crowi#access_token', '')
let g:crowi#filetypes = get(g:, 'crowi#filetypes', [])
let g:crowi#open_page = get(g:, 'crowi#open_page', true)
let g:crowi#default_create_path = get(g:, 'crowi#default_create_path',
            \ '/user/'.expand('$USER').'/メモ/'.strftime("%Y/%m/%d", localtime())
            \ )
let g:crowi#browser_command = get(g:, 'crowi#browser_command', '')

if globpath(&rtp, 'autoload/webapi/http.vim') ==# ''
  echohl ErrorMsg | echomsg 'You must install https://github.com/mattn/webapi-vim' | echohl None
  finish
endif

function! crowi#create() abort
  if g:crowi#api_url ==# ''
    echohl ErrorMsg | echomsg 'g:crowi#api_url is empty' | echohl None
    return
  endif
  if g:crowi#access_token ==# ''
    echohl ErrorMsg | echomsg 'g:crowi#access_token is empty' | echohl None
    return
  endif
  if !s:is_creatable_filetype()
    echohl ErrorMsg | echomsg printf('"%s" is not accept type', &filetype) | echohl None
    return
  endif
  let path = s:generate_path(expand('%:r'))
  let content = s:get_current_buffer()
  if s:ask_no_interrupt(path . ': OK?')
    " ok
  else
    let path = s:prompt('> ', s:generate_path())
    if path ==# '' || path !~ '^/'
      echohl ErrorMsg | echomsg printf('"%s" is invalid path', path) | echohl None
      return
    endif
  endif
  let res = webapi#http#post(g:crowi#api_url . '/_api/pages.create', {
        \ 'access_token': g:crowi#access_token,
        \ 'path': path,
        \ 'body': content,
        \ })
  let crowi = webapi#json#decode(res.content)
  if crowi.ok
    if g:crowi#open_page
      call s:open_browser(g:crowi#api_url . '/' . crowi.page.id)
    endif
    echomsg printf('Successfully created: %s', path)
  else
    echohl ErrorMsg | echomsg printf('%s %s', crowi.error, path) | echohl None
  endif
endfunction

function! s:ask_no_interrupt(...)
  try
    return call('s:ask', a:000)
  catch
    return 0
  endtry
endfunction

function! s:ask(message, ...)
  call inputsave()
  echohl WarningMsg
  let answer = input(a:message.(a:0 ? ' (y/N/a) ' : ' (y/N) '))
  echohl None
  call inputrestore()
  echo "\r"
  return (a:0 && answer =~? '^a') ? 2 : (answer =~? '^y') ? 1 : 0
endfunction

function! s:prompt(prompt, ...)
  call inputsave()
  echohl WarningMsg
  let answer = len(a:000) > 0 ? input(a:prompt, a:000[0]) : input(a:prompt)
  echohl None
  call inputrestore()
  echo "\r"
  return answer
endfunction

function! s:generate_path(...)
  let path = g:crowi#default_create_path . '/'
  let path .= len(a:000) > 0 ? a:000[0] : ''
  return path
endfunction

function! s:get_current_buffer()
  return join(getline(1, line('$')), "\n")
endfunction

function! s:get_browser_command() abort
  let cmd = g:crowi#browser_command
  if cmd ==# ''
    if has('win32') || has('win64')
      let cmd = '!start rundll32 url.dll,FileProtocolHandler %URL%'
    elseif has('mac') || has('macunix') || has('gui_macvim') || system('uname') =~? '^darwin'
      let cmd = 'open %URL%'
    elseif executable('xdg-open')
      let cmd = 'xdg-open %URL%'
    elseif executable('firefox')
      let cmd = 'firefox %URL% &'
    else
      let cmd = ''
    endif
  endif
  return cmd
endfunction

function! s:open_browser(url) abort
  let cmd = s:get_browser_command()
  if cmd ==# ''
    redraw
    echohl WarningMsg | echo 'Open URL below manually' | echohl None
    echo a:url
    return
  endif
  let quote = &shellxquote == '"' ?  "'" : '"'
  if cmd =~# '^!'
    let cmd = substitute(cmd, '%URL%', '\=quote.a:url.quote', 'g')
    let g:hoge = cmd
    silent! exec cmd
  elseif cmd =~# '^:[A-Z]'
    let cmd = substitute(cmd, '%URL%', '\=a:url', 'g')
    exec cmd
  else
    let cmd = substitute(cmd, '%URL%', '\=quote.a:url.quote', 'g')
    call system(cmd)
  endif
endfunction

function! s:is_creatable_filetype()
  return len(g:crowi#filetypes) == 0 || match(g:crowi#filetypes, &filetype) != -1
endfunction
