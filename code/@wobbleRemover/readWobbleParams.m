function success=readWobbleParams(obj)
    % Read cached wobble parameters from .mat file on disk 
    success=false;

    if obj.simulatedMode
        success=false;
        return
    end

    % Find the settings directory
    SETTINGS_DIR = strrep(which('wobbleRemover'), '@wobbleRemover/wobbleRemover.m','settingsWobbleRemover');
    fname = fullfile(SETTINGS_DIR,obj.paramsFname);
    if ~exist(fname)
        return
    end

    load(fname)

    obj.toggleWobbleParamListeners(false)
    obj.phase=lastWobble.phase;
    obj.amplitude=lastWobble.amplitude;

    obj.toggleWobbleParamListeners(true)
    obj.wavelength=lastWobble.wavelength; %So this triggers make wobble model
end %readWobbleParams
