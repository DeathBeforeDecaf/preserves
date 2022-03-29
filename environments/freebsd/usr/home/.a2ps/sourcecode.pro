% -*-postscript-*-
% PostScript Prologue for a2ps (Colored)
%
% $Id: color.pro,v 1.1.1.1.2.1 2007/12/29 01:58:27 mhatta Exp $
%

%
% This file is part of a2ps.
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 3, or (at your option)
% any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; see the file COPYING.  If not, write to
% the Free Software Foundation, 59 Temple Place - Suite 330,
% Boston, MA 02111-1307, USA.
%
Documentation
Colors are used to highlight the keywords.
EndDocumentation
% -- code follows this line --
%%IncludeResource: file base.ps
%%IncludeResource: file sourcecode.hdr
%%BeginResource: procset a2ps-sourcecode-prolog 2.0 1
%%DocumentProcessColors: Red Green Blue

%% Definition of the color faces.
/p {
  0 0 0 FG
  false BG
  false UL
  false BX
%Face: Plain Courier bfs
  Show
} bind def

/sy {
  0 0 0 FG
  false BG
%Face: Symbol Symbol bfs
  Show
} bind def

/k {
  0.1 0.1 0.8 FG
  false BG
  false UL
  false BX
%Face: Keyword Courier bfs
  Show
} bind def

/K {
  0.3 0.3 0.9 FG
  false BG
  false UL
  false BX
%Face: Keyword_strong Courier-Bold bfs
  Show
} bind def

/c {
  0.2 0.7 0.7 FG
  false BG
  false UL
  false BX
%Face: Comment Courier bfs
  Show
} bind def

/C {
  0.2 0.7 0.7 FG
  false BG
  false UL
  false BX
%Face: Comment_strong Courier-Bold bfs
  Show
} bind def

/l {
  0.9 0.1 0.9 FG
  false BG
  false UL
  false BX
%Face: Label Courier bfs
  Show
} bind def

/L {
  0.9 0.1 0.9 FG
  false BG
  false UL
  false BX
%Face: Label_strong Courier-Bold bfs
  Show
} bind def

/str {
  0.6 0.6 0.6 FG
  false BG
  false UL
  false BX
%Face: String Courier bfs
  Show
} bind def

/e{
  1 1 1 FG
  1 0 0 true BG
  false UL
  true BX
%Face: Error Helvetica-Bold bfs
  Show
} bind def

% Function print line number (<string> # -)
/# {
  gsave
    sx cw mul 2 div neg 0 rmoveto
    f# setfont
    0.8 0.1 0.1 FG
    c-show
  grestore
} bind def
%%EndResource
%%BeginSetup
% The font for line numbering
/f# /Helvetica findfont bfs .6 mul scalefont def
%%EndSetup
