%SCHEMER_IMPORT Import a color theme into MATLAB
%   SCHEMER_IMPORT() with no input will prompt the user to locate the
%   color theme source file via the GUI.
%   
%   SCHEMER_IMPORT(FILENAME) imports the color scheme options given in
%   the file FILENAME. 
%   
%   SCHEMER_IMPORT(...,INCLUDEBOOLS) can control whether boolean
%   preferences are included in import (default: FALSE). If INCLUDEBOOLS
%   is set to true, boolean preference options such as whether to
%   highlight autofixable errors, or to show variables with shared scope in
%   a different color will also be overridden, should they be set in the
%   input file.
%   Note: input order is reversible, so the command
%   SCHEMER_IMPORT(INCLUDEBOOLS,FILENAME) will also work and
%   SCHEMER_IMPORT(INCLUDEBOOLS) with boolean input will open the GUI
%   to pick the file.
%   
%   RET = SCHEMER_IMPORT(...) returns 1 on success, 0 on user
%   cancellation at input file selection screen, -1 on fopen error, and -2
%   on any other error.
%   
%   NOTE:
%   The color theme file to import can either be
%   generated by SCHEME_EXPORT, or a MATLAB preferences file, such as
%   the file at FULLFILE(PREFDIR,'matlab.prf') taken from a different
%   computer or previous MATLAB installation. However, if you are importing
%   from a matlab.prf file you should be aware that any color preferences
%   which have been left as the defaults on preference panels which the
%   user has not visited on the origin system of the matlab.prf file will
%   not be present in the file, and hence not updated on import.
%   By default, MATLAB preference options which will be overwritten by
%   SCHEMER_IMPORT are:
%   - All settings in the Color pane of Preferencs
%   - All color settings in the Color > Programming Tools pane, but no
%     checkboxes
%   - From Editor/Debugger > Display pane, the following:
%      - Highlight current line (color, but not whether to)
%      - Right-hand text limit (color and thickness, but not on/off)
%   Once the current color preferences are overridden they cannot be
%   undone, so it is recommended that you export your current preferences
%   with SCHEME_EXPORT before importing a new theme if you think you
%   may wish to revert.
%   
%   For more details on how to get and set MATLAB preferences with
%   commands, see the following URL.
%   http://undocumentedmatlab.com/blog/changing-system-preferences-programmatically/
%   
%   If you wish to revert to the default MATLAB color scheme, it is
%   recommended you import the file defaultmatlabtheme.prf included in this
%   package. This will reset Editor/Debugger>Display colors as well as the
%   colors set in the Colors pane.
%   
%   See also SCHEMER_EXPORT, PREFDIR.

% Copyright (c) 2013, Scott Lowe
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are
% met:
%     * Redistributions of source code must retain the above copyright
%       notice, this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright
%       notice, this list of conditions and the following disclaimer in
%       the documentation and/or other materials provided with the distribution
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.

% Known issues:
% 1. Text color of automatically highlighted variables does not change
%   color immediately. This is an issue with matlab; if you change the main
%   text color in the preferences pane, highlighted variables will still
%   have the old text color until matlab is restarted.
% 2. Java exception is thrown on Windows when trying to update
%   Editor.VariableHighlighting.Color. This only happens the first
%   time SCHEMER_IMPORT is run, so the current fix is to catch the error
%   and then try again. However, it might be possible for other Java
%   exceptions get thrown under other mysterious circumstances, which could 
%   cause the function to fail.

function varargout = schemer_import(fname, inc_bools)

VERSION = 'v1.0.2';

% ------------------------ Input handling ---------------------------------
% ------------------------ Default inputs ---------------------------------
if nargin<2
    inc_bools = false; % Default off, so only override extra options if intended
end
if nargin<1
    fname = []; % Ask user to select file
end
% Input switching
if nargin>=1 && ~ischar(fname) && ~isempty(fname)
    if ~islogical(fname) && ~isnumeric(fname)
        error('Invalid input argument 1');
    end
    if nargin==1
        % First input omitted
        inc_bools = fname;
        fname = [];
    elseif ischar(inc_bools)
        % Inputs switched
        tmp = fname;
        fname = inc_bools;
        inc_bools = tmp;
        clear tmp;
    else
        error('Invalid combination of inputs');
    end
end

% ------------------------ Check for file ---------------------------------
filefilt = ...
   {'*.prf;*.txt','Text and pref files (*.prf, *.txt)'; ...
    '*.*',  'All Files (*.*)'};

if ~isempty(fname)
    if ~exist(fname,'file')
        error('Specified file does not exist');
    end
else
    % Dialog asking for input filename
    % Need to make this dialogue include .txt by default, at least
    [filename, pathname] = uigetfile(filefilt);
    % End if user cancels
    if isequal(filename,0);
        if nargout>0; varargout{1} = 0; end;
        return;
    end
    fname = fullfile(pathname,filename);
end

% ------------------------ Catch block ------------------------------------
% Somewhat inexplicably, when the code is run on Windows R2011a to load a
% new color scheme, a Java exception is thrown. But if you try again
% immediately, you will succeed. The problem is very consistent.
% No such issues occur for Linux R2011a.
try
    [varargout{1:nargout}] = main(fname, inc_bools);
catch ME
    if ~strcmp(ME.identifier,'MATLAB:Java:GenericException');
        rethrow(ME);
    end
%     disp('Threw and ignored a Java exception. Retrying.');
    [varargout{1:nargout}] = main(fname, inc_bools);
end

end

% ======================== Main code ======================================
function varargout = main(fname, inc_bools)

% ------------------------ Parameters -------------------------------------
names_boolean = {                                   ...
    'ColorsUseSystem'                               ... % Color:    Desktop:    Use system colors
};
names_boolextra = {                                 ...
    'ColorsUseMLintAutoFixBackground'               ... % Color>PT: Analyser:   autofix highlight
    'Editor.VariableHighlighting.Automatic'         ... % Color>PT: Var&fn:     auto highlight
    'Editor.NonlocalVariableHighlighting'           ... % Color>PT: Var&fn:     with shared scope
    'EditorCodepadHighVisible'                      ... % Color>PT: CellDisp:   highlight cells
    'EditorCodeBlockDividers'                       ... % Color>PT: CellDisp:   show lines between cells
    'Editorhighlight-caret-row-boolean'             ... % Editor>Display:       Highlight current line
    'EditorRightTextLineVisible'                    ... % Editor>Display:       Show Right-hand text limit
};
names_integer = {                                   ...
    'EditorRightTextLimitLineWidth'                 ... % Editor>Display:       Right-hand text limit Width
};
names_color = {                                     ...
    'ColorsText'                                    ... % Color:    Desktop:    main text color
    'ColorsBackground'                              ... % Color:    Desktop:    main background
    'Colors_M_Keywords'                             ... % Color:    Syntax:     keywords
    'Colors_M_Comments'                             ... % Color:    Syntax:     comments
    'Colors_M_Strings'                              ... % Color:    Syntax:     strings
    'Colors_M_UnterminatedStrings'                  ... % Color:    Syntax:     unterminated strings
    'Colors_M_SystemCommands'                       ... % Color:    Syntax:     system commands
    'Colors_M_Errors'                               ... % Color:    Syntax:     errors
    'Colors_HTML_HTMLLinks'                         ... % Color:    Other:      hyperlinks
    'Colors_M_Warnings'                             ... % Color>PT: Analyser:   warnings
    'ColorsMLintAutoFixBackground'                  ... % Color>PT: Analyser:   autofix
    'Editor.VariableHighlighting.Color'             ... % Color>PT: Var&fn:     highlight
    'Editor.NonlocalVariableHighlighting.TextColor' ... % Color>PT: Var&fn:     with shared scope
    'Editorhighlight-lines'                         ... % Color>PT: CellDisp:   highlight
    'Editorhighlight-caret-row-boolean-color'       ... % Editor>Display:       Highlight current line Color
    'EditorRightTextLimitLineColor'                 ... % Editor>Display:       Right-hand text limit line Color
};

verbose = 0;

% ------------------------ Setup ------------------------------------------
if nargout==0
    varargout = {};
else
    varargout = {-2};
end
if inc_bools
    names_boolean = [names_boolean names_boolextra];
end

% ------------------------ File stuff -------------------------------------
% Open for read access only
fid = fopen(fname,'r','n');
if isequal(fid,-1);
    if nargout>0; varargout{1} = -1; end;
    return;
end
% Add a cleanup object incase of failure
finishup = onCleanup(@() fclose(fid));

% ------------------------ Read and Write ---------------------------------
while ~feof(fid)
    % Get one line of preferences/theme file
    l = fgetl(fid);
    
    % Ignore empty lines and lines which begin with #
    if length(l)<1 || strcmp('#',l(1))
        if verbose; disp('Comment'); end;
        continue;
    end
    
    % Look for name pref pair, seperated by '='
    %    Must be at begining of string (hence ^ anchor)
    %    Cannot contain comment marker (#)
    n = regexp(l,'^(?<name>[^=#]+)=(?<pref>[^#]+)','names');
    
    % If no match, continue and scan next line
    if isempty(n)
        if verbose; disp('No match'); end;
        continue;
    end
    
    % Trim whitespace from pref
    n.pref = strtrim(n.pref);
    
    if ismember(n.name,names_boolean)
        % Deal with boolean type
        switch lower(n.pref)
            case 'btrue'
                % Preference is true
                com.mathworks.services.Prefs.setBooleanPref(n.name,1);
                if verbose; fprintf('Set bool true %s\n',n.name); end
            case 'bfalse'
                % Preference is false
                com.mathworks.services.Prefs.setBooleanPref(n.name,0);
                if verbose; fprintf('Set bool false %s\n',n.name); end
            otherwise
                % Shouldn't be anything else
                warning('Bad boolean for %s: %s',n.name,n.pref);
        end
        
    elseif ismember(n.name,names_integer)
        % Deal with integer type
        if ~strcmpi('I',n.pref(1))
            warning('Bad integer pref for %s: %s',n.name,n.pref);
            continue;
        end
        int = str2double(n.pref(2:end));
        com.mathworks.services.Prefs.setIntegerPref(n.name,int);
        if verbose; fprintf('Set integer %d for %s\n',int,n.name); end
    
    elseif ismember(n.name,names_color)
        % Deal with color type (final type to consider)
        if ~strcmpi('C',n.pref(1))
            warning('Bad color for %s: %s',n.name,n.pref);
            continue;
        end
        rgb = str2double(n.pref(2:end));
        jc = java.awt.Color(rgb);
        com.mathworks.services.Prefs.setColorPref(n.name, jc);
        com.mathworks.services.ColorPrefs.notifyColorListeners(n.name);
        if verbose
            fprintf('Set color (%3.f, %3.f, %3.f) for %s\n',...
                jc.getRed, jc.getGreen, jc.getBlue, n.name);
        end
        
    else
        % Silently ignore irrelevant preferences
        % (This means you can load a whole matlab.pref file and anything not
        % listed above as relevant to the color theme will be ignored.)
        
    end
    
end

% ------------------------ Tidy up ----------------------------------------
% fclose(fid); % Don't need to close as it will autoclose
if nargout>0; varargout{1} = 1; end;

if inc_bools
    fprintf('Imported color scheme WITH boolean options from\n%s\n',fname);
else
    fprintf('Imported color scheme WITHOUT boolean options from\n%s\n',fname);
end

end
