" keep recommended defaults (vim >= 8)
unlet! skip_defaults_vim
source $VIMRUNTIME/defaults.vim

" allow jumping to matching element
runtime macros/matchit.vim

" remap the leader to space
nnoremap <SPACE> <Nop>
let mapleader=","

" set font
set guifont=Iosevka\ Term\ 10

" Disable compatibility with vi which can cause unexpected issues.
set nocompatible

" Enable type file detection. Vim will be able to try to detect the type of file in use.
filetype on

" Enable plugins and load plugin for the detected file type.
filetype plugin on

" Load an indent file for the detected file type.
filetype indent on

" Turn syntax highlighting on.
syntax on

" Set shift width to 4 spaces.
set shiftwidth=4

" Set tab width to 4 columns.
set tabstop=4

" Use space characters instead of tabs.
set expandtab

" Do not save backup files.
set nobackup

" Do not let cursor scroll below or above N number of lines when scrolling.
set scrolloff=10

" softwrap
set wrap linebreak

" While searching though a file incrementally highlight matching characters as you type.
set incsearch

" Ignore capital letters during search.
set ignorecase

" Override the ignorecase option if searching for capital letters.
" This will allow you to search specifically for capital letters.
set smartcase

" Show partial command you type in the last line of the screen.
set showcmd

" Show the mode you are on the last line.
set showmode

" Show matching words during a search.
set showmatch

" Use highlighting when doing a search.
set hlsearch

" Set the commands to save in history default number is 20.
set history=1000

" show line numbers
set number

" highlight current line
set cursorline

" Enable auto completion menu after pressing TAB.
"set wildmenu

" Make wildmenu behave like similar to Bash completion.
" set wildmode=list:longest
"set confirm

" There are certain files that we would never want to edit with Vim.
" Wildmenu will ignore files with these extensions.
set wildignore=*.docx,*.jpg,*.png,*.gif,*.pdf,*.pyc,*.exe,*.flv,*.img,*.xlsx  

" enable mouse (for tmux)
set mouse=a

" auto install plug if not installed
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" Specify a directory for plugins
call plug#begin('~/.vim/plugged')

" search
" note: we need both fzf commands
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
" Plug 'jremmen/vim-ripgrep'

" general
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-flagship'
Plug 'tpope/vim-abolish'

" add-ons
Plug 'tpope/vim-fugitive'
Plug 'idanarye/vim-merginal'
Plug 'preservim/nerdtree'

" language support
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'kergoth/vim-bitbake'
Plug 'sheerun/vim-polyglot'
Plug 'honza/vim-snippets'
Plug 'mlaursen/vim-react-snippets'

" color schemes
Plug 'YorickPeterse/vim-paper'
Plug 'axvr/photon.vim'
Plug 'NLKNguyen/papercolor-theme'
Plug 'junegunn/seoul256.vim'

" Initialize plugin system
call plug#end()

" set colorscheme
set t_Co=256
set background=light
colorscheme=seoul256

" Enable per-command history
" - History files will be stored in the specified directory
" - When set, CTRL-N and CTRL-P will be bound to 'next-history' and
"   'previous-history' instead of 'down' and 'up'.
let g:fzf_history_dir = '~/.local/share/fzf-history'

" header/source switch using related filenames 
nnoremap <silent> <C-h> :CocCommand clangd.switchSourceHeader<CR>

" edit this file
nnoremap <silent> <Leader>ve :e ~/configuration/vimrc.vim<CR>
" reload this file
nnoremap <silent> <Leader>vr :source ~/configuration/vimrc.vim<CR>

" current buffer
nnoremap <silent> <C-b> :Buffer<CR>

" files
nnoremap <silent> <C-p> :Files<CR>
nnoremap <silent> <Leader><C-p> :GFiles<CR>

" search current buffer for current word
nnoremap <silent> <Leader><C-f> :BLines <C-R><C-W><CR>

" search current word in all files
nnoremap <silent> <Leader>F :Ag <C-R><C-W><CR>

" fuzzy global search contents of default buffer
nnoremap <silent> <Leader>ss :Ag <C-R>"<CR>

" explore current wd
nnoremap <silent> <Leader>x :Explore <CR>

" wrap current line
nnoremap <silent> <Leader>w :gqq<CR>

" system clipboard interaction
noremap <Leader>y "*y
noremap <Leader>p "*p
noremap <Leader>Y "+y
noremap <Leader>P "+p

" search current word in tags
function! FzfTagsCurrentWord()
  let l:word = expand('<cword>')
  let l:list = taglist(l:word)
  if len(l:list) == 1
    execute ':tag ' . l:word
  else
    call fzf#vim#tags(l:word)
  endif
endfunction
noremap <Leader>st :call FzfTagsCurrentWord()<CR>

" look here and up for local tags
set tag=./tags,tags;

" Customize fzf colors to match color scheme
" - fzf#wrap translates this to a set of `--color` options
let g:fzf_colors =
\ { 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':     ['bg', 'Normal'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'Normal'],
  \ 'border':  ['fg', 'Ignore'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment'] }

" customize Ag to have better (the same as above) colors.
command! -bang -nargs=* Ag call fzf#vim#ag(<q-args>, '--color-path "1;36"', fzf#vim#with_preview(), <bang>0)

" vim hardcodes background color erase even if the terminfo file does
" not contain bce (not to mention that libvte based terminals
" incorrectly contain bce in their terminfo files). This causes
" incorrect background rendering when using a color theme with a
" background color.
let &t_ut=''

" show vertical line after end of textwidth
set colorcolumn=+1

" set textwidth
set textwidth=100

" nerdtree bindings
nnoremap <leader>nt :NERDTreeToggle<CR>
nnoremap <leader>nf :NERDTreeFind<CR>
nnoremap <leader>nh :NERDTreeCWD<CR>
let g:NERDTreeWinSize=60

" format current document using prettier
command! -nargs=0 Prettier :CocCommand prettier.forceFormatDocument

" coc configuration
source ~/configuration/coc.vim
