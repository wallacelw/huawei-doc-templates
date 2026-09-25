%% guide.cls
%% =====================================================================
%%  LaTeX class for Huawei Cloud guides
%%  Requires XeLaTeX or LuaLaTeX (due to fontspec).
%%
%%  All shared boilerplate lives in templates/_base/huawei-base.cls:
%%    - Class options (portuguese, indentbody, notime, nochangelog,
%%      noauthors); any other option is passed to the article class.
%%    - \LoadClass of article (a4paper, 10pt) and all package loads.
%%    - The 13 shared modules from templates/_base/ (huawei-colors,
%%      huawei-fonts, huawei-lang, huawei-page, huawei-tables,
%%      huawei-code, huawei-callouts, huawei-images, huawei-changelog,
%%      huawei-titles, huawei-toc, huawei-cover, huawei-shared).
%%    - \setdoctitle (shared cover title setter).
%%  This class adds only guide-specific commands.
%%
%%  Fonts:
%%    - Body : HarmonyOS Sans (fallback: Liberation Sans)
%%    - Code : Cascadia Code (fallback: DejaVu Sans Mono)
%% =====================================================================
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{guide}[2026/09/26 Huawei Guide template v6.14.1]

% ---- Base class (options, article, packages, shared modules) ---------
\LoadClassWithOptions{huawei-base}

% ---- Cover (shared) -----------------------------------------------
% \setdoctitle{...}  -> large cover title (and default header)
% (defined in huawei-base)
\newcommand{\setguidetitle}[1]{\setdoctitle{#1}}% backward-compatible alias

\endinput
