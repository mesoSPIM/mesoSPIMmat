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

    U = unique(obj.wobbleModel.wobble);

    for ii=1:length(U)
        f=find(obj.wobbleModel.wobble==U(ii));
        obj.imData.imStack(:,:,f) = circshift(obj.imData.imStack(:,:,f), scaleFactor*U(ii));
    end


end % correctStack
