function imData = generateTestingImage(~)
    % generateTestingImage
    %
    % Produces a test image to aid development when no dataset is available

    imData = mesotools.metaDataReader('example.raw_meta.txt');

    % Generate a data volume
    dataSize = 2^6;
    imData.imStack = repmat(peaks(dataSize),[1,1,dataSize]);
    for ii=1:size(imData.imStack,3)
        imData.imStack(:,:,ii) = circshift(imData.imStack(:,:,ii),ii);
    end

    % Rotate it and make it uint16
    imData.imStack = permute(imData.imStack,[3,1,2]);
    %imData.imStack = (imData.imStack -  min(imData.imStack(:))); %zeroing the lower half makes the data easier to see
    imData.imStack = (imData.imStack ./ max(imData.imStack(:))) * 2^16;
    imData.imStack = cast(imData.imStack,'uint16');


    % Get the meta-data to match the image
    imData.frames = 1:size(imData.imStack,3);
    imData.z_planes=size(imData.imStack,3);
    imData.POSITION.z_planes=size(imData.imStack,3);
    imData.POSITION.z_stepsize = 10;
    imData.z_stepsize = 10;
    imData.POSITION.z_end = imData.POSITION.z_start + size(imData.imStack,3)*imData.POSITION.z_stepsize;
end
