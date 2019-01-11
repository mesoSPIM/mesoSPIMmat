function metaData = metaDataReader(fname)
    % Read raw image meta-data
    %
    % function metaData = mesotools.metaDataReader(fname)
    %
    % Inputs
    % fname - may be either the full name (with relative or abs path if 
    %.        not in current directory) or the unique first part. e.g.
    %         'cerebellum.raw_data.txt' or 'cerebellum'
    %
    % Outputs
    % metaData - a structure containing the meta data
    %
    %
    % Rob Campbell - SWC 2019


    metaData=struct;

    %handles cases where the user does not supply the extension
    if ~exist(fname,'file')
        % Then try stripping extensions and generating a file name
        [pathToFile,tmpFname] = fileparts(fname);
        processedFname = regexprep(tmpFname,'\..*','');
        processedFname = fullfile(pathToFile,processedFname);
        fnameNew = [processedFname,'.raw_meta.txt'];

        if ~exist(fnameNew ,'file')
            fprintf('Can not find %s or %s -- Not reading metaData\n',...
                fname, fnameNew)
        else
            fname = fnameNew;
        end
    end

    if ~exist(fname,'file')
        return
    end


    fid = fopen(fname,'r');

    currentSubStructName=[];

    while ~feof(fid)
        tline = fgetl(fid);
        if isempty(tline)
            continue
        end

        % Parse the line
        tok=regexp(tline,'\[(.*)\] ?(.*)','tokens');
        tok=tok{1};

        if isempty(tok{2}) || strcmp(tok{2},' ')
            currentSubStructName = fixDirtyFieldName(tok{1});
            continue
        end



        thisField = fixDirtyFieldName(tok{1});
        thisVar = mungeVariable(tok{2});

        if ~isempty(currentSubStructName)
            metaData.(currentSubStructName).(thisField) = thisVar;
        else
            metaData.(thisField) = thisVar;
        end

    end


    fclose(fid);

end %close main function body




function fName = fixDirtyFieldName(fName)
    % Fix dirty field names
    fName = strrep(fName,' ','_');
    fName = strrep(fName,'(%)','');
end %fixDirtyFieldName


function var = mungeVariable(var)
    % Convert numbers to numerics and leave the rest as strings

    if isempty(str2num(var))
        return
    else
        var = str2num(var);
    end
end %mungeVariable

