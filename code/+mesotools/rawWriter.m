function rawWriter(imDataStruct,fname)
    % Write image stack to raw data file "fname"
    %
    % function mesotools.rawWriter(imDataStruct,fname)
    %
    % Purpose
    % Write mesoSPIM raw data file from a structure that was read in by
    % the function mesotools.rawReader
    %
    % Inputs
    % imDataStruct - the output of mesotools.rawReader
    % fname - string containing the file name. e.g. 'cortex_xyz01'
    %
    %
    % Rob Campbell - SWC 2019
    %
    % See also: mesotools.rawReader


    if nargin<2 || ~isstruct(imDataStruct) || ~ischar(fname)
        fprintf('\n ** INCORRECT INPUT ARGUMENTS **\n\n')
        help(['mesotools.',mfilename])
        return
    end

    % Strip any extensions
    fname = regexprep(fname,'\..*','');


    %Write the raw data
    rawFname = [fname,'.raw'];
    fprintf('Writing image data to %s\n', rawFname)
    fid = fopen(rawFname, 'w');
    fwrite(fid,imDataStruct.imStack(:),'uint16','ieee-le');
    fclose(fid);


    % Write the raw data textfile
    metaFname = [fname,'.raw_meta.txt'];
    fprintf('Writing meta-data to %s\n', metaFname)

    fid = fopen(metaFname,'w');

    rootFields = fields(imDataStruct);
    for ii = 1:length(rootFields)
        tField = rootFields{ii};

        if strcmp(tField,'imStack') || ...
            strcmp(tField,'frames')
            continue
        end


        if ~isstruct(imDataStruct.(tField))
            if regexp(tField,'Metadata')
                fprintf(fid, '[%s]', strrep(tField,'_',' '));
            else
                fprintf(fid, '[%s]', tField);
            end
            if ischar(imDataStruct.(tField))
                fprintf(fid,' %s\n', imDataStruct.(tField));
            else
                fprintf(fid,' %0.2f\n', imDataStruct.(tField));
            end
            continue
        end

        fprintf(fid, '\n[%s]\n',strrep(tField,'_',' '));

        subStruct = imDataStruct.(tField);
        
        subFields = fields(subStruct);
        for jj = 1:length(subFields)
            
            if regexp(subFields{jj},'Intensity ?')
                fprintf(fid, '[%s]', 'Intensity (%)');
            elseif regexp(subFields{jj},'ETL ')
                fprintf(fid, '[%s]',strrep(subFields{jj},'_',' '));
            else
                fprintf(fid, '[%s]', subFields{jj});
            end

            tjVar = subStruct.(subFields{jj});
            if ischar(tjVar)
                fprintf(fid,' %s\n', tjVar);
            elseif rem(tjVar,1)==0 || tjVar==0
                fprintf(fid,' %d\n', tjVar);
            elseif tjVar < 1E-3
                fprintf(fid,' %0.2e\n', tjVar);
            else
                fprintf(fid,' %0.2f\n', tjVar);
            end
        end % for jj

    end % for ii

    fclose(fid);


end
