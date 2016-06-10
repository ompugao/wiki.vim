" vimwiki
"
" Maintainer: Karl Yngve Lervåg
" Email:      karl.yngve@gmail.com
"

"
" Main functions
"
function! vimwiki#diary#make_note(wnum, ...) "{{{
  if a:wnum > len(g:vimwiki_list)
    echomsg 'Vimwiki Error: Wiki '.a:wnum.' is not registered in g:vimwiki_list!'
    return
  endif

  " TODO: refactor it. base#goto_index uses the same
  if a:wnum > 0
    let idx = a:wnum - 1
  else
    let idx = 0
  endif

  call vimwiki#path#mkdir(vimwiki#opts#get('path', idx).vimwiki#opts#get('diary_rel_path', idx))

  if a:0 && a:1 == 1
    let cmd = 'tabedit'
  else
    let cmd = 'edit'
  endif
  if a:0>1
    let link = 'diary:'.a:2
  else
    let link = 'diary:'.s:diary_date_link(idx)
  endif

  call vimwiki#base#open_link(cmd, link, s:diary_index(idx))
  call vimwiki#base#setup_buffer_state(idx)
endfunction "}}}
function! vimwiki#diary#goto_diary_index(wnum) "{{{
  if a:wnum > len(g:vimwiki_list)
    echomsg 'Vimwiki Error: Wiki '.a:wnum.' is not registered in g:vimwiki_list!'
    return
  endif

  " TODO: refactor it. base#goto_index uses the same
  if a:wnum > 0
    let idx = a:wnum - 1
  else
    let idx = 0
  endif

  call vimwiki#base#edit_file('e', s:diary_index(idx), '')
  call vimwiki#base#setup_buffer_state(idx)
endfunction "}}}
function! vimwiki#diary#goto_next_day() "{{{
  let link = ''
  let [idx, links] = s:get_position_links(expand('%:t:r'))

  if idx == (len(links) - 1)
    return
  endif

  if idx != -1 && idx < len(links) - 1
    let link = 'diary:'.links[idx+1]
  else
    " goto today
    let link = 'diary:'.s:diary_date_link()
  endif

  if len(link)
    call vimwiki#base#open_link(':e ', link)
  endif
endfunction "}}}
function! vimwiki#diary#goto_prev_day() "{{{
  let link = ''
  let [idx, links] = s:get_position_links(expand('%:t:r'))

  if idx == 0
    return
  endif

  if idx > 0
    let link = 'diary:'.links[idx-1]
  else
    " goto today
    let link = 'diary:'.s:diary_date_link()
  endif

  if len(link)
    call vimwiki#base#open_link(':e ', link)
  endif
endfunction "}}}
function! vimwiki#diary#generate_diary_section() "{{{
  let current_file = vimwiki#path#path_norm(expand("%:p"))
  let diary_file = vimwiki#path#path_norm(s:diary_index())
  if vimwiki#path#is_equal(current_file, diary_file)
    let content_rx = '^\%(\s*\* \)\|\%(^\s*$\)\|\%('.g:vimwiki_rxHeader.'\)'
    call vimwiki#base#update_listing_in_buffer(s:format_diary(),
          \ vimwiki#opts#get('diary_header'), content_rx, line('$')+1, 1)
  else
    echomsg 'Vimwiki Error: You can generate diary links only in a diary index page!'
  endif
endfunction "}}}

"
" Calendar.vim integration
"
function! vimwiki#diary#calendar_action(day, month, year, week, dir) "{{{
  let day = s:prefix_zero(a:day)
  let month = s:prefix_zero(a:month)

  let link = a:year.'-'.month.'-'.day
  if winnr('#') == 0
    if a:dir ==? 'V'
      vsplit
    else
      split
    endif
  else
    wincmd p
    if !&hidden && &modified
      new
    endif
  endif

  " XXX: Well, +1 is for inconsistent index basing...
  call vimwiki#diary#make_note(g:vimwiki_current_idx+1, 0, link)
endfunction "}}}
function! vimwiki#diary#calendar_sign(day, month, year) "{{{
  let day = s:prefix_zero(a:day)
  let month = s:prefix_zero(a:month)
  let sfile = vimwiki#opts#get('path').vimwiki#opts#get('diary_rel_path').
        \ a:year.'-'.month.'-'.day.vimwiki#opts#get('ext')
  return filereadable(expand(sfile))
endfunction "}}}

"
" Helpers
"
function! s:prefix_zero(num) "{{{
  if a:num < 10
    return '0'.a:num
  endif
  return a:num
endfunction "}}}
function! s:get_date_link(fmt) "{{{
  return strftime(a:fmt)
endfunction "}}}
function! s:diary_path(...) "{{{
  let idx = a:0 == 0 ? g:vimwiki_current_idx : a:1
  return vimwiki#opts#get('path', idx).vimwiki#opts#get('diary_rel_path', idx)
endfunction "}}}
function! s:diary_index(...) "{{{
  let idx = a:0 == 0 ? g:vimwiki_current_idx : a:1
  return s:diary_path(idx).vimwiki#opts#get('diary_index', idx).vimwiki#opts#get('ext', idx)
endfunction "}}}
function! s:diary_date_link(...) "{{{
  let idx = a:0 == 0 ? g:vimwiki_current_idx : a:1
  return s:get_date_link(vimwiki#opts#get('diary_link_fmt', idx))
endfunction "}}}
function! s:get_position_links(link) "{{{
  let idx = -1
  let links = []
  if a:link =~# '^\d\{4}-\d\d-\d\d'
    let links = keys(s:get_diary_links())
    " include 'today' into links
    if index(links, s:diary_date_link()) == -1
      call add(links, s:diary_date_link())
    endif
    call sort(links)
    let idx = index(links, a:link)
  endif
  return [idx, links]
endfunction "}}}
function! s:get_month_name(month) "{{{
  return g:vimwiki_diary_months[str2nr(a:month)]
endfunction "}}}

"
" Diary index stuff
"
let s:vimwiki_max_scan_for_caption = 5
function! s:read_captions(files) "{{{
  let result = {}
  for fl in a:files
    " remove paths and extensions
    let fl_key = fnamemodify(fl, ':t:r')

    if filereadable(fl)
      for line in readfile(fl, '', s:vimwiki_max_scan_for_caption)
        if line =~# g:vimwiki_rxHeader && !has_key(result, fl_key)
          let result[fl_key] = vimwiki#u#trim(matchstr(line, g:vimwiki_rxHeader))
        endif
      endfor
    endif

    if !has_key(result, fl_key)
      let result[fl_key] = ''
    endif

  endfor
  return result
endfunction "}}}
function! s:get_diary_links() "{{{
  let rx = '^\d\{4}-\d\d-\d\d'
  let s_files = glob(vimwiki#opts#get('path').vimwiki#opts#get('diary_rel_path').'*'.vimwiki#opts#get('ext'))
  let files = split(s_files, '\n')
  call filter(files, 'fnamemodify(v:val, ":t") =~# "'.escape(rx, '\').'"')

  " remove backup files (.wiki~)
  call filter(files, 'v:val !~# ''.*\~$''')

  let links_with_captions = s:read_captions(files)

  return links_with_captions
endfunction "}}}
function! s:group_links(links) "{{{
  let result = {}
  let p_year = 0
  let p_month = 0
  for fl in sort(keys(a:links))
    let year = strpart(fl, 0, 4)
    let month = strpart(fl, 5, 2)
    if p_year != year
      let result[year] = {}
      let p_month = 0
    endif
    if p_month != month
      let result[year][month] = {}
    endif
    let result[year][month][fl] = a:links[fl]
    let p_year = year
    let p_month = month
  endfor
  return result
endfunction "}}}
function! s:sort(lst) "{{{
  if vimwiki#opts#get("diary_sort") ==? 'desc'
    return reverse(sort(a:lst))
  else
    return sort(a:lst)
  endif
endfunction "}}}
function! s:format_diary() "{{{
  let result = []

  let g_files = s:group_links(s:get_diary_links())

  for year in s:sort(keys(g_files))
    call add(result, '')
    call add(result, substitute(g:vimwiki_rxH2_Template, '__Header__', year , ''))

    for month in s:sort(keys(g_files[year]))
      call add(result, '')
      call add(result, substitute(g:vimwiki_rxH3_Template, '__Header__', s:get_month_name(month), ''))

      for [fl, cap] in s:sort(items(g_files[year][month]))
        if empty(cap)
          let entry = substitute(g:vimwiki_WikiLinkTemplate1, '__LinkUrl__', fl, '')
          let entry = substitute(entry, '__LinkDescription__', cap, '')
          call add(result, repeat(' ', &sw).'* '.entry)
        else
          let entry = substitute(g:vimwiki_WikiLinkTemplate2, '__LinkUrl__', fl, '')
          let entry = substitute(entry, '__LinkDescription__', cap, '')
          call add(result, repeat(' ', &sw).'* '.entry)
        endif
      endfor

    endfor
  endfor

  return result
endfunction "}}}

" vim: fdm=marker sw=2
