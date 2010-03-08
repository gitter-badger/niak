function [files_in,files_out,opt] = niak_brick_nu_correct(files_in,files_out,opt)
%
% _________________________________________________________________________
% SUMMARY NIAK_BRICK_NU_CORRECT
%
% Non-uniformity correction on a T1 scan. See comments for details on the
% algorithm. 
%
% SYNTAX:
% [FILES_IN,FILES_OUT,OPT] = NIAK_BRICK_NU_CORRECT(FILES_IN,FILES_OUT,OPT)
%
% _________________________________________________________________________
% INPUTS
%
%  * FILES_IN        
%       (structure) with the following fields :
%
%       T1
%           (string) the file name of a T1 volume.
%
%       MASK
%           (string, default '') the file name of a binary mask of a region
%           of interest. If left empty, no mask is specified.
%
%  * FILES_OUT
%       (structure) with the following fields.  Note that if a field is an 
%       empty string, a default value will be used to name the outputs. 
%       If a field is ommited, the output won't be saved at all (this is 
%       equivalent to setting up the output file names to 
%       'gb_niak_omitted'). 
%                       
%       T1_NU
%           (string, default <FILES_IN.T1>_NU.<EXT>) The non-uniformity
%           corrected T1 scan.
%
%       T1_IMP
%           (string, default <FILES_IN.T1>_NU.IMP) The estimated
%           intensity mapping.
%
%  * OPT           
%       (structure) with the following fields:
%
%       ARG
%           (string, default '') any argument that will be passed to the
%           NU_CORRECT command (see comments below). 
%
%       FLAG_VERBOSE 
%           (boolean, default: 1) If FLAG_VERBOSE == 1, write
%           messages indicating progress.
%
%       FLAG_TEST 
%           (boolean, default: 0) if FLAG_TEST equals 1, the brick does not 
%           do anything but update the default values in FILES_IN, 
%           FILES_OUT and OPT.
%
%       FOLDER_OUT 
%           (string, default: path of FILES_IN) If present, all default 
%           outputs will be created in the folder FOLDER_OUT. The folder 
%           needs to be created beforehand.
%               
% _________________________________________________________________________
% OUTPUTS
%
% The structures FILES_IN, FILES_OUT and OPT are updated with default
% valued. If OPT.FLAG_TEST == 0, the specified outputs are written.
%
% _________________________________________________________________________
% SEE ALSO:
% NIAK_BRICK_MASK_BRAIN_T1, NIAK_PIPELINE_ANAT_PREPROCESS
%
% _________________________________________________________________________
% COMMENTS:
%
% NOTE 1:
%   This function is a simple NIAK-compliant wrapper around the minc tool
%   called NU_CORRECT. Type "nu_correct -help" in a terminal for more
%   infos.
%
% NOTE 2:
%   The correction method is N3 [1], and should work with any MR volume 
%   including raw (non-stereotaxic) data.  The performance of this method 
%   can be enhanced by supplying a mask for the region of interest.
%
%   [1] J.G. Sled, A.P. Zijdenbos and A.C. Evans, "A non-parametric method
%       for automatic correction of intensity non-uniformity in MRI data",
%       in "IEEE Transactions on Medical Imaging", vol. 17, n. 1,
%       pp. 87-97, 1998 
%
% Copyright (c) Pierre Bellec, McConnell Brain Imaging Center, 
% Montreal Neurological Institute, McGill University, 2008.
% Maintainer : pbellec@bic.mni.mcgill.ca
% See licensing information in the code.
% Keywords : medical imaging, T1, non-uniformity correction

% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE.

flag_gb_niak_fast_gb = true;
niak_gb_vars; % load important NIAK variables

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Seting up default arguments %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Syntax
if ~exist('files_in','var')|~exist('files_out','var')
    error('niak:brick','syntax: [FILES_IN,FILES_OUT,OPT] = NIAK_BRICK_NU_CORRECT(FILES_IN,FILES_OUT,OPT).\n Type ''help niak_brick_nu_correct'' for more info.')
end

%% Input files
gb_name_structure = 'files_in';
gb_list_fields = {'t1','mask'};
gb_list_defaults = {NaN,'gb_niak_omitted'};
niak_set_defaults

%% Output files
gb_name_structure = 'files_out';
gb_list_fields = {'t1_nu','t1_imp'};
gb_list_defaults = {'gb_niak_omitted','gb_niak_omitted'};
niak_set_defaults

%% Options
gb_name_structure = 'opt';
gb_list_fields = {'arg','flag_verbose','folder_out','flag_test'};
gb_list_defaults = {'',true,'',false};
niak_set_defaults

%% Building default output names
[path_f,name_f,ext_f] = fileparts(files_in.t1);
if isempty(path_f)
    path_f = '.';
end

if strcmp(ext_f,gb_niak_zip_ext)    
    [tmp,name_f,ext_f] = fileparts(name_f);
    ext_f = cat(2,ext_f,gb_niak_zip_ext);
end

if strcmp(opt.folder_out,'')
    opt.folder_out = path_f;
end

if isempty(files_out.t1_nu)    
    files_out.t1_nu = [opt.folder_out,filesep,name_f,'_nu',ext_f];
end

if isempty(files_out.t1_imp)    
    files_out.t1_imp = [opt.folder_out,filesep,name_f,'_nu.imp'];
end

if flag_test == 1    
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% The brick starts here %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

if flag_verbose
    msg = 'Non-uniformity correction on T1 volume';
    stars = repmat('*',[1 length(msg)]);
    fprintf('\n%s\n%s\n%s\n',stars,msg,stars);    
end

%% Setting up the system call to NU_CORRECT
[path_f,name_f,ext_f] = fileparts(files_out.t1_nu);
flag_zip = strcmp(ext_f,gb_niak_zip_ext);

path_tmp = niak_path_tmp(['_' name_f]);
file_tmp_nu = [path_tmp 't1_nu.mnc'];
file_tmp_imp = [path_tmp 't1_nu.imp'];

if isempty(arg)
    if strcmp(files_in.mask,'gb_niak_omitted')
        instr = ['nu_correct -tmpdir ' path_tmp ' ' files_in.t1 ' ' file_tmp_nu];
    else
        instr = ['nu_correct -tmpdir ' path_tmp ' -mask ' files_in.mask ' ' files_in.t1 ' ' file_tmp_nu];
    end
else
    if strcmp(files_in.mask,'gb_niak_omitted')
        instr = ['nu_correct -tmpdir ' path_tmp ' ' arg ' ' files_in.t1 ' ' file_tmp_nu];
    else
        instr = ['nu_correct -tmpdir ' path_tmp ' ' arg ' -mask ' files_in.mask ' ' files_in.t1 ' ' file_tmp_nu];
    end
end

%% Running NU_CORRECT
if flag_verbose
    fprintf('Running NU_CORRECT with the following command:\n%s\n\n',instr)
end

if flag_verbose
    system(instr)
else
    [status,msg] = system(instr);
    if status~=0
        error('The nu_correct command failed with that error message :\n%s\n',msg);
    end
end

%% Writting outputs
if ~strcmp(files_out.t1_nu,'gb_niak_omitted')
    if flag_zip
        system([gb_niak_zip ' ' file_tmp_nu]);        
        system(['mv ' file_tmp_nu gb_niak_zip_ext ' ' files_out.t1_nu]);
    else
        system(['mv ' file_tmp_nu ' ' files_out.t1_nu]);
    end
end

if ~strcmp(files_out.t1_imp,'gb_niak_omitted')
    system(['mv ' file_tmp_imp ' ' files_out.t1_imp]);    
end

system(['rm -rf ' path_tmp]);

