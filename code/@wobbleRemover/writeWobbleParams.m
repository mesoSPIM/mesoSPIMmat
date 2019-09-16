function writeWobbleParams(obj)
    % Writes current wobble parameters to a mat file for later re-use
    if obj.simulatedMode
        return
    end
    lastWobble.phase = obj.phase;
    lastWobble.amplitude = obj.amplitude;
    lastWobble.wavelength = obj.wavelength;
    lastWobble.offset = min(obj.wobbleModel.zVals);

    SETTINGS_DIR = regexprep(which('wobbleRemover'), '@wobble.*$','settingsWobbleRemover');
    if ~exist(SETTINGS_DIR,'dir')
        fprintf('No directory %s for saving last used parameters.\n', SETTINGS_DIR)
        return
    end
    fname = fullfile(SETTINGS_DIR,obj.paramsFname);
    save(fname,'lastWobble')
end %writeWobbleParams

