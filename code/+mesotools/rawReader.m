function imData = rawReader(fname,frames)
    % Read raw image data and return as a structure along with meta-data
    %
    % function imData = mesotools.rawReader(fname,frame)
    %
    % Inputs
    % fname - may be either the full name (with relative or abs path if 
    %.       not in current directory) or the unique first part. e.g.
    %       'cerebellum.raw' or 'cerebellum'
    % frames - vector or scalar indictating which frames to read. If missing,
    %         all frames are read
    %
    % Output
    % imData - structure containing meta-data and the image stack. 
    %.         The image stack is in the "imStack" field. The 
    %          identity of each frame is stored in the "frames" field.
    %
    %
    % Examples
    % >> IM = mesotools.rawReader('cereb.raw'); %read the whole file
    %
    % >> IM = mesotools.rawReader('cereb.raw',[20,50,100]); %read a subset of frames
    % >> imagesc(IM.imStack(:,:,3)); %display frame 100
    %
    % Rob Campbell - SWC 2019

    imData=[];

    if nargin==0
        return
    end

    if nargin<2
        frames=inf;
    end

    %handles cases where the user does not supply the extension
    if ~exist(fname,'file')
        % Then try stripping extensions and generating a file name
        [pathToFile,tmpFname] = fileparts(fname);
        processedFname = regexprep(tmpFname,'\..*','');
        processedFname = fullfile(pathToFile,processedFname);
        fnameNew = [processedFname,'.raw'];

        if ~exist(fnameNew ,'file')
            fprintf('Can not find %s or %s -- Not reading image data\n',...
                fname, fnameNew)
            return
        else
            fname = fnameNew;
        end
    end

    % Read metaData
    imData = mesotools.metaDataReader(regexprep(fname,'\..*',''));


    pixelsPerFrame = 2048^2; % HARD CODE FOR NOW

    fid = fopen(fname,'r','ieee-le');

    if frames==inf
        % Find out how many frames there are in the file:
        fseek(fid,0,'eof');
        nFrames = ftell(fid)/((2048^2)*2);
        fseek(fid,0,'bof');
        fprintf('Reading %d frames\n',nFrames)
        frames = 1:nFrames;
    end

    if nFrames~=imData.z_planes
        fprintf('Found %d frames but metaData reports %d franes\n',...
            nFrames, imData.z_planes)
    end

    imData.imStack = zeros([2048,2048,length(frames)], 'uint16');
    n=1;
    for ii=1:length(frames)
        thisPos = frames(ii)-1; %because fseek is zero-indexed
        startPoint = thisPos * pixelsPerFrame * 2; %because there are 2 bytes per 16 bit int
        fseek(fid,startPoint,'bof');
        imData.imStack(:,:,n) = reshape(fread(fid,pixelsPerFrame,'uint16'),[2048,2048]);
        n=n+1;
    end % for ii
    imData.frames = frames;

    fclose(fid);

end
