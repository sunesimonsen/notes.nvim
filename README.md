# Notes.nvim

A note taking system that will last forever.

This [Neovim](https://neovim.io/) plugin manages [Markdown](https://en.wikipedia.org/wiki/Markdown) files in a
single folder with a file naming scheme supporting efficient searching.

https://github.com/user-attachments/assets/91f7b555-86d0-4518-9e1d-c3d328c78c68

## Installation

```lua
return {
  'sunesimonsen/notes.nvim',
  dependencies = { 'nvim-telescope/telescope.nvim', },
  opts = {
    dir = '/Users/ssimonsen/Library/CloudStorage/Dropbox/denoted',
  },
  keys = {
    { '<leader>nn', ':Notes find<CR>', desc = 'Find note', mode = { 'n' } },
    { '<leader>nl', ':Notes link_to_note<CR>', desc = 'Link to note', mode = { 'n' } },
    { '<leader>nr', ':Notes retitle<CR>', desc = 'Retitle note', mode = { 'n' } },
    { '<leader>ns', ':Notes search<CR>', desc = 'Search through notes', mode = { 'n' } },
    { '<leader>nt', ':Notes toggle_tag<CR>', desc = 'Toggle tag', mode = { 'n' } },
  },
  lazy = false,
}

```

## File naming scheme

The file naming convention is crucial for efficient searching and organization. Each file name follows a specific syntax:

### Example File name

```
20230504T162825--configuring-neovim__editor_tools.md
```

### Breakdown of the file name

- **ID**: A UTC timestamp indicating when the file was created.
- **Title**: Starts with `--` and includes one or more title words, each separated by `-`.
- **Tags**: An optional section starting with `__`, containing tags that begin with `_`.
- **Extension**: Currently, only Markdown files (`.md`) are supported.

For more details see the [regular expression](#regular-expression-for-file-names) and [BNF](#bnf-for-file-names) section below.

## Search patterns

Here are some ideas on how to search for notes.

### Finding all notes with the tag `unix`

```sh
ls | grep '_unix'
```

### Finding all notes with the title having a word starting with config

```sh
ls | grep '-config'
```

### Finding all notes with either a tag or the title containing the word `config`

```sh
ls | grep 'config'
```

### Finding all notes that was created between 12-15 in 2022

```sh
ls | grep '^2022' | grep 'T1[2-5]'
```

## BNF for file names

The file name has the following syntax:

```ebnf
<filename> ::= <id> "--" <title> ( "__" <tags> )? ".md"

<id> ::= <date> "T" <time>

<date> ::= <year> <month> <day>
<year> ::= <digit> <digit> <digit> <digit>
<month> ::= <digit> <digit>
<day> ::= <digit> <digit>

<time> ::= <hour> <minute> <second>
<hour> ::= <digit> <digit>
<minute> ::= <digit> <digit>
<second> ::= <digit> <digit>


<title> ::= <word> ( "-" <word> )*
<tags> ::= <tag> ( "_" <tag> )*
<tag> ::= <word>

<word> ::= ( <letter> | <digit> )+
<letter> ::= "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j" | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" | "w" | "x" | "y" | "z"
<digit> ::= "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
```


## Regular expression for file names

```
\d{8}T\d{6}-(-[a-z0-9]+)+(_(_[a-z0-9]+)+)?\.md
```

## Acknowledgments

The plugin is heavily inspired by [Denote for Emacs](https://protesilaos.com/emacs/denote).

## License

[MIT © Sune Simonsen](./LICENSE)
