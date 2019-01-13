function correctStack(obj,reverseCorrect)
    % Run the correction over the whole stack and replace data in RAM

    % reverseCorrect is used for the simulated data mode to apply the wobble
    % to the simulated stack
    if nargin<2
        reverseCorrect=false;
    end

    if reverseCorrect
        scaleFactor = 1;
    else
        scaleFactor = -1;
    end

    for ii = 1:size(obj.imData.imStack,3)
        tSlice = squeeze(obj.imData.imStack(:,:,ii));
        tWobble = round(obj.wobbleModel.wobble(ii)) * scaleFactor;
        obj.imData.imStack(:,:,ii) = circshift(tSlice, tWobble);
    end
end % correctStack
