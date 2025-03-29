function! s:ResolveDenote(val)
    let id = substitute(a:val, '\.id$', '', '')
    return globpath(expand('%:p:h'), id . '*')
endfunction

setlocal includeexpr=s:ResolveDenote(v:fname)
