function saveData(obj,overwrite)
    % Saves stack to disk (optionally replaces the original data with the corrected data)
    % TODO - Also must note in the meta-data text file how the correction was done
    % TODO - Also write to the file the current Git commit of wobbleRemover

    if nargin<2
        overwrite=false;
    end


    fname = regexprep(obj.imData.Metadata_for_file,'.*/','');

    if overwrite==false
        fname = [fname,'_DEWOBBLE'];
    end

    mesotools.rawWriter(obj.imData, fname)

    % If we replaced the data, the wobble params must be good so write them to disk
    obj.writeWobbleParams 
end %saveData
