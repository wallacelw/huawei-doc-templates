%% poc.cls
%% =====================================================================
%%  Huawei POC/Homologation Template — Proof of Concept and technical
%%  homologation documents for Huawei Cloud.
%%
%%  Structure:
%%    1. Cover page (title, subtitle, client, version, date, authors)
%%    2. Table of contents
%%    3. Preamble: Executive Summary, Background, Goal & Objectives,
%%       Solution Overview
%%    4. Scope & Planning: Scope, Premises, Methodology, Activities,
%%       Schedule, Responsibility Matrix
%%    5. Conclusion: Expected Results, Actual Results, Comments,
%%       Conclusion, Signatures
%%    6. Changelog (optional)
%%
%%  Class options:
%%    portuguese  -> uses Portuguese for predefined labels and babel.
%%                   (default: English)
%%    indentbody  -> indents all running text by \contentindent.
%%                   (default: off)
%%    notime      -> hides the compilation time on the cover.
%%                   (default: show time)
%%    nochangelog -> suppresses the changelog section entirely
%%                   and hides version/date/time on the cover page.
%%                   (default: show changelog)
%%    noauthors   -> hides the authors on the cover page.
%%                   (default: show authors if set)
%%    <any>       -> passed to the article class.
%% =====================================================================
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{poc}[2026/09/18 Huawei POC template v6.2.7]

% ---- Options --------------------------------------------------------
\newif\if@indentbody \@indentbodyfalse
\DeclareOption{indentbody}{\@indentbodytrue}
\newif\if@portuguese \@portuguesefalse
\DeclareOption{portuguese}{\@portuguesetrue}
\newif\if@showtime \@showtimetrue
\DeclareOption{notime}{\@showtimefalse}
\newif\if@changelog \@changelogtrue
\DeclareOption{nochangelog}{\@changelogfalse}
\newif\if@showauthors \@showauthorstrue
\DeclareOption{noauthors}{\@showauthorsfalse}
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax
\LoadClass[a4paper,10pt]{article}

% ---- Packages -------------------------------------------------------
\RequirePackage[a4paper,top=3cm,bottom=3cm,left=2cm,right=2cm,%
                headheight=1.4cm,headsep=0.7cm]{geometry}
\RequirePackage{fontspec}
\PassOptionsToPackage{table}{xcolor}
\RequirePackage{xcolor}
\RequirePackage{graphicx}
\RequirePackage{fancyhdr}
\RequirePackage{titlesec}
\RequirePackage[titles]{tocloft}
\RequirePackage{enumitem}
\RequirePackage{fancyvrb}
\RequirePackage{fvextra}
\fvset{breaklines,breakanywhere}
\RequirePackage[most]{tcolorbox}
\RequirePackage{etoolbox}
\RequirePackage{booktabs}
\RequirePackage{array}
\RequirePackage{tabularx}
\RequirePackage{babel}
\if@portuguese
  \babelprovide[import,main]{brazilian}
\else
  \babelprovide[import,main]{english}
\fi
\RequirePackage{hyperref}
\RequirePackage{caption}
\RequirePackage{float}
\RequirePackage{longtable}
\RequirePackage{amssymb}
\RequirePackage{seqsplit}

% ---- Shared modules (templates/_base/) ------------------------------
\RequirePackage{huawei-colors}
\RequirePackage{huawei-fonts}
\RequirePackage{huawei-lang}
\RequirePackage{huawei-page}
\RequirePackage{huawei-tables}
\RequirePackage{huawei-code}
\RequirePackage{huawei-callouts}
\RequirePackage{huawei-images}
\RequirePackage{huawei-changelog}
\RequirePackage{huawei-titles}
\RequirePackage{huawei-toc}
\RequirePackage{huawei-cover}
\RequirePackage{huawei-shared}
\RequirePackage{huawei-badges}

% =====================================================================
%  LANGUAGE-AWARE LABELS
% =====================================================================
\if@portuguese
  % POC result labels
  \newcommand{\lg@pocpass}{Atendido}
  \newcommand{\lg@pocpartial}{Parcial}
  \newcommand{\lg@pocfail}{Falha}
  \newcommand{\lg@pocskip}{Ignorado}
  % Closing record labels
  \newcommand{\lg@closingitem}{Item}
  \newcommand{\lg@closingrecord}{Registro}
  % Signature labels
  \newcommand{\lg@siggreeting}{At.te,}
  \newcommand{\lg@sigemail}{E-mail}
  % POC classification
  \newcommand{\lg@pochomologated}{Homologada}
  \newcommand{\lg@pocwithreservations}{Homologada com ressalvas}
  \newcommand{\lg@pocnothomologated}{Não homologada}
\else
  % POC result labels
  \newcommand{\lg@pocpass}{Pass}
  \newcommand{\lg@pocpartial}{Partial}
  \newcommand{\lg@pocfail}{Fail}
  \newcommand{\lg@pocskip}{Skip}
  % Closing record labels
  \newcommand{\lg@closingitem}{Item}
  \newcommand{\lg@closingrecord}{Record}
  % Signature labels
  \newcommand{\lg@siggreeting}{Sincerely,}
  \newcommand{\lg@sigemail}{E-mail}
  % POC classification
  \newcommand{\lg@pochomologated}{Homologated}
  \newcommand{\lg@pocwithreservations}{With reservations}
  \newcommand{\lg@pocnothomologated}{Not homologated}
\fi

% ---- Cover ----------------------------------------------------------
\newcommand{\setdoctitle}[1]{\renewcommand{\lg@doctitle}{#1}}
\newcommand{\setpoctitle}[1]{\setdoctitle{#1}}

% =====================================================================
%  POC RESULT BADGE
% =====================================================================
% Visual badge for POC/homologation results.
% Usage: \pocresult{Pass}  \pocresult{Partial}  \pocresult{Fail}  \pocresult{Skip}
% Labels are language-aware (Atendido / Pass, etc.)

\newcommand{\pocresult}[1]{%
  \ifstrequal{#1}{Pass}{%
    \huaweibadge{tipbg}{tipfg}{\lg@pocpass}%
  }{%
    \ifstrequal{#1}{Partial}{%
      \huaweibadge{warningbg}{warningfg}{\lg@pocpartial}%
    }{%
      \ifstrequal{#1}{Fail}{%
        \huaweibadge{red!15}{huaweired}{\lg@pocfail}%
      }{%
        \ifstrequal{#1}{Skip}{%
          \huaweibadge{codebg}{ruleblack}{\lg@pocskip}%
        }{%
          \huaweibadge{codebg}{ruleblack}{#1}%
        }%
      }%
    }%
  }%
}

% =====================================================================
%  OBJECTIVE BLOCK
% =====================================================================
% Highlighted box for the goal statement in Section 3.
% Usage:
%   \begin{objectiveblock}
%   Migrate the application to Huawei Cloud ...
%   \end{objectiveblock}

\newenvironment{objectiveblock}{%
  \begin{tcolorbox}[
    enhanced jigsaw, breakable,
    colback=infobg, colframe=infofg,
    boxrule=1pt, arc=3pt,
    left=8pt, right=8pt, top=6pt, bottom=6pt,
  ]
}{%
  \end{tcolorbox}
}

% =====================================================================
%  STAKEHOLDERS TABLE
% =====================================================================
% Contact table grouped by organization.
% Usage (passthrough block):
%   \begin{stakeholders}
%   \stakeholderorg{Organization Name}
%   \stakeholderrow{Name}{email}{phone}{role}
%   \stakeholderorg{Another Org}
%   \stakeholderrow{Name}{email}{phone}{role}
%   \end{stakeholders}

\newenvironment{stakeholders}{%
  \par
  \renewcommand{\arraystretch}{1.3}%
  \noindent
  \begin{tabular}{|>{\RaggedRight\arraybackslash}m{\dimexpr(\linewidth-5\arrayrulewidth-8\tabcolsep)*15/100\relax}|>{\RaggedRight\arraybackslash}m{\dimexpr(\linewidth-5\arrayrulewidth-8\tabcolsep)*35/100\relax}|>{\RaggedRight\arraybackslash}m{\dimexpr(\linewidth-5\arrayrulewidth-8\tabcolsep)*20/100\relax}|>{\RaggedRight\arraybackslash}m{\dimexpr(\linewidth-5\arrayrulewidth-8\tabcolsep)*30/100\relax}|}
  \hline
}{%
  \end{tabular}%
  \par
}
\newcommand{\stakeholderorg}[1]{%
  \rowcolor{huaweired}\multicolumn{4}{|>{\RaggedRight\arraybackslash}m{\dimexpr\linewidth-2\tabcolsep-2\arrayrulewidth\relax}|}{\color{white}\textbf{#1}} \\ \hline
}
\newcommand{\stakeholderrow}[4]{#1 & \seqsplit{#2} & #3 & #4 \\ \hline}

% =====================================================================
%  CLOSING RECORD
% =====================================================================
% Final classification table with checkboxes.
% Usage (passthrough block):
%   \begin{closingrecord}
%   \closingrow{Preliminary result}{\checkbox{Homologated} \checkbox{With reservations}}
%   \closingrow{Critical pending items}{}
%   \closingrow{Deadline for evidence}{2026-12-31}
%   \closingrow{Responsibles}{Jane Doe}
%   \closingrow{Final observations}{}
%   \end{closingrecord}

\newenvironment{closingrecord}{%
  \par
  \renewcommand{\arraystretch}{1.5}%
  \noindent
  \begin{tabular}{|>{\RaggedRight\arraybackslash}m{\dimexpr(\linewidth-3\arrayrulewidth-4\tabcolsep)*30/100\relax}|>{\RaggedRight\arraybackslash}m{\dimexpr(\linewidth-3\arrayrulewidth-4\tabcolsep)*70/100\relax}|}
  \hline
  \rowcolor{huaweired}
  {\color{white}\bfseries\lg@closingitem} & {\color{white}\bfseries\lg@closingrecord} \\
  \hline
}{%
  \end{tabular}%
  \par
}
\newcommand{\closingrow}[2]{#1 & #2 \\ \hline}
\newcommand{\checkbox}[1]{$\square$~#1}

% =====================================================================
%  SIGNATURES
% =====================================================================
% Formal sign-off block — 2x2 grid.
% Use \signaturecell for each cell, with & and \\ \hline explicitly.
% Usage (passthrough block):
%   \begin{signatures}
%   \signaturecell{Name}{Title}{email}{Address} & \signaturecell{Name}{Title}{email}{Address} \\ \hline
%   \signaturecell{Name}{Title}{email}{Address} & \signaturecell{Name}{Title}{email}{Address} \\ \hline
%   \end{signatures}

\newenvironment{signatures}{%
  \par
  \begin{tabular}{|>{\RaggedRight\arraybackslash}m{\dimexpr(\linewidth-3\arrayrulewidth-4\tabcolsep)/2\relax}|>{\RaggedRight\arraybackslash}m{\dimexpr(\linewidth-3\arrayrulewidth-4\tabcolsep)/2\relax}|}
  \hline
}{%
  \end{tabular}%
  \par
}
\newcommand{\signaturecell}[4]{%
  \lg@siggreeting \par\medskip
  \textbf{#1} \par
  #2 \par
  \textbf{\lg@sigemail:} \texttt{\seqsplit{#3}} \par
  #4 \par\bigskip
}

\endinput
