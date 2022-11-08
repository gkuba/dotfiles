" BASIC SETTINGS:
" Sets 256 color support, encoding, status, history, nowrap, line numbers, and
" cursor.
set t_Co=256
set encoding=utf-8
set laststatus=2
set history=1000
set cursorline
set nowrap
set number

" Set Color Scheme
packadd! dracula
colorscheme dracula

" Search down into subfolders
" Provides tab-completion for all file-related tasks
set path+=**

" Display all matching files when we tab complete
set wildmenu
set wildmode=list:longest,full

" NOW WE CAN:
" - Hit tab to :find by partial match
" - Use * to make it fuzzy

" THINGS TO CONSIDER:
" - :b lets you autocomplete any open buffer

" Disables vi compatability
set nocompatible

" Enable syntax and plugins
syntax enable
filetype plugin on

" PATHOGEN PLUGIN ARGS:
" Sets the Pathogen args for Powerline and NERDTree
execute pathogen#infect()
let g:airline_powerline_fonts = 1
let g:airline_theme = 'deus'
autocmd vimenter * if !argc() | NERDTree | endif
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTreeType") && b:NERDTreeType == "primary") | q | endif
let NERDTreeMinimalUI=1

set history=1000
set cursorline
set nowrap
set number

" KEY MAPPINGS:
"Global Remappings
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>
