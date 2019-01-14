function makeWobbleModel(obj,~,~)
    % wobbleRemover.makeWobbleModel
    %
    % This method creates the sinewave approximating the stage wobble motion

    zRange = [obj.imData.POSTION.z_start, obj.imData.POSTION.z_end];
    if zRange(1)>zRange(2)
        zRange=fliplr(zRange);
        flipped=true;
    else
        flipped=false;
    end

    %Use a relative zero but store the offset as it will be useful in future. 
    zVals = zRange(1) : obj.imData.z_stepsize : (zRange(2)-obj.imData.z_stepsize);
    zVals = zVals-min(zVals); %TODO- implement the offset properly so we can use different stacks

    if flipped
        zVals = fliplr(zVals);
    end

    if length(zVals) ~= size(obj.imData.imStack,3)
        fprintf('ERROR: Wobble model has %d data points but there are %d z-planes in the dataset\n',...
            length(zVals),size(obj.imData.imStack,3))
    end

    % The values in Z in this image (i.e. the stage coords for each plane)

    waveForm = sin( obj.phase + (((zVals/obj.wavelength)) *2*pi) );
    MICRONS_PER_PIXEL = 1;
    waveForm = (waveForm / MICRONS_PER_PIXEL) * (obj.amplitude/2);

    % We now have a scaled waveform we can overlay
    obj.wobbleModel.wobble = round(waveForm); %Round to the nearest pixel, we won't do sub-pixel
    obj.wobbleModel.zVals = zVals;

    obj.updatePlottedPlanes
end % makeWobbleLine