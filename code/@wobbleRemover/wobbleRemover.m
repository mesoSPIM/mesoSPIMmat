classdef wobbleRemover < handle

    properties (SetObservable)
        phase=0 % Phase of the wobble with respect to the zero of the stage
        amplitude=20 % amplitude in microns
        wavelength=500

        % Images taken from the re-slice that is parallel to the optical table
        originalImage
        correctedImage

        slicePlane % Which plane to plot
    end % properties (SetObservable)

    properties % properties
        hFig
        hWobble % The plot handle of the guide line to show the wobble we are modeling
        hOrigAx % Axis of original image
        hCorrectedAx % Axis of corrected image
        hOrigIm % Handle to image object for original image
        hCorrectedIm  % Handle to image object for corrected image

        imData % The full stack and associated meta-data
    end

    properties (Hidden,SetObservable)
        wobbleModel %This is the sine wave that models the wobble
    end % (Hidden,SetObservable)

    properties (Hidden)
        paramsFname = 'lastGoodWobbleParams.mat' %Last known good parameters are stored in this fname in the "settings" directory
        listeners = {}
        wobbleParamListeners = {};
    end % (Hidden)



    methods

        %CONSTRUCTOR
        function obj = wobbleRemover(fname)
            % Manual interface for removing parasitic motion from mesoSPIM z-stacks
            %
            % W = wobbleRemover(fname)
            %
            % Purpose
            % Some of the original mesoSPIMs have z-drives which translate side to side
            % ("wobble") as they move in z. This originates from play in the lead-screw
            % and should have a period of 500 microns. The amplitude and phase will vary
            % from system to system but are consistent within a system from run to run. 
            % This tool models the error as a sine wave and cancels it out.
            %
            % The tool works manually, so the user must decide which parameters are suitable. 
            % This is **CURRENTLY AN EARLY VERSION**. To use:
            %
            % EITHER: W = wobbleRemove('MyFile.raw');
            % OR: data = mesotools.rawReader('MyFile.raw'); W = wobbleRemove(data);
            %
            % Find a nice plane to view:
            % W.slicePlane
            %
            % Then modify the following parameters and observe results:
            % W.amplitude
            % W.phase
            % W.wavelength %shouldn't need much tweaking
            %
            % When you're happy you can save the data
            % W.saveData %Creates a new file with "_DEWOBBLE" appended to the name
            % W.saveData(true) %Over-write original (DANGEROUS!)
            %
            %
            % Rob Campbell - SWC 2019


            % If fname is a file name, the stack is read. If it's a structure, it's treated as 
            % being the output of mesotools.rawReader
            if ischar(fname)
                obj.imStack = mesotools.rawReader(fname);
            elseif isstruct(fname)
                obj.imData = fname;
            elseif isempty(obj.imData)
                return
            end



            obj.slicePlane=round(size(obj.imData.imStack,1)/2); %TODO: choose more cleverly?
            obj.originalImage = squeeze(obj.imData.imStack(:,obj.slicePlane,:));
            obj.correctedImage = squeeze(obj.imData.imStack(:,obj.slicePlane,:));


            % Set up the figure window
            obj.hFig = clf;
            obj.hOrigAx = subplot(1,2,1);

            obj.hOrigIm = imagesc(obj.originalImage);
            hold on
            obj.hWobble = plot(nan,nan,'-r');
            obj.hOrigAx = gca;
            title('Original image')
            axis off

            obj.hCorrectedAx = subplot(1,2,2);
            obj.hCorrectedIm = imagesc(obj.correctedImage);
            obj.hCorrectedAx = gca;
            title('Corrected image')
            axis off

            colormap gray

            obj.hFig.CloseRequestFcn = @obj.figClose; %Closing figure deletes object


            % obj.plotWobbleLine should run when wobbleModel updates
            % obj.runImageCorrection should run when wobbleModel updates
            % obj.makeWobbleModel should run when phase, amplitude, or wavelength are changed (implement as method to enable/disable)

            % The correctedImage plot should update whenever the corrected data change


            obj.makeWobbleModel %Model wobble as a sine wave

            if obj.readWobbleParams %If the file is there then we must have successfully ran the correction
                %The model will update and make the line
            else
                % Force making the line with the defaults present in the wobbleRemover properties
                obj.makeWobbleModel %Model wobble as a sine wave
            end

            % Set up listeners
            obj.listeners{end+1} = addlistener(obj, 'slicePlane', 'PostSet', @obj.updatePlottedPlanes);
            obj.listeners{end+1} = addlistener(obj, 'wobbleModel', 'PostSet', @obj.plotWobbleLine);

            obj.wobbleParamListeners{end+1} = addlistener(obj, 'phase', 'PostSet', @obj.makeWobbleModel);
            obj.wobbleParamListeners{end+1} = addlistener(obj, 'amplitude', 'PostSet', @obj.makeWobbleModel);
            obj.wobbleParamListeners{end+1} = addlistener(obj, 'wavelength', 'PostSet', @obj.makeWobbleModel);
        end % wobbleRemover

        %DESTRUCTOR
        function delete(obj)
            cellfun(@delete,obj.listeners)
        end % delete

        function figClose(obj,~,~)
            delete(obj.hFig) %close figure
            obj.delete %class destructor
        end




        function updatePlottedPlanes(obj,~,~)
            obj.originalImage = squeeze(obj.imData.imStack(:,obj.slicePlane,:));
            obj.hOrigIm.CData = obj.originalImage;
            obj.plotWobbleLine
            obj.runImageCorrection;
        end


        function toggelWobbleParamListeners(obj,enableDisableBool)
            % input arg should be true/false
            for ii=1:length(obj.wobbleParamListeners)
                obj.wobbleParamListeners.Enabled = enableDisableBool;
            end
        end


        function makeWobbleModel(obj,~,~)
            zRange = [obj.imData.POSTION.z_start, obj.imData.POSTION.z_end];
            if zRange(1)>zRange(2)
                zRange=fliplr(zRange);
                flipped=true;
            else
                flipped=false;
            end
            zVals = zRange(1) : obj.imData.z_stepsize : (zRange(2)-obj.imData.z_stepsize);
            if flipped
                zVals = fliplr(zVals);
            end

             % The values in Z in this image (i.e. the stage coords for each plane)
            waveForm = sin( obj.phase + (((zVals/obj.wavelength)) *2*pi) );
            MICRONS_PER_PIXEL = 1;
            waveForm = (waveForm / MICRONS_PER_PIXEL) * (obj.amplitude/2);

            % We now have a scaled waveform we can overlay
            obj.wobbleModel.wobble = waveForm;
            obj.wobbleModel.zVals = zVals;

            obj.runImageCorrection 
        end % makeWobbleLine



        function correctStack(obj)
            for ii=1:length(obj.wobbleModel.wobble)
                tWobble = round(obj.wobbleModel.wobble(ii)) * -1;
                obj.correctedImage(:,ii) = circshift(obj.originalImage(:,ii), tWobble);
            end
            % Use the current parameters to correct the full stack
            obj.hCorrectedIm.CData = obj.correctedImage;
        end

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
        end


        function success=readWobbleParams(obj)
            success=false;

            % Find the settings directory
            SETTINGS_DIR = strrep(which('wobbleRemover'), '@wobbleRemover/wobbleRemover.m','settingsWobbleRemover');
            fname = fullfile(SETTINGS_DIR,obj.paramsFname);
            if ~exist(fname)
                return
            end

            load(fname)

            obj.toggelWobbleParamListeners(false)
            obj.phase=lastWobble.phase;
            obj.amplitude=lastWobble.amplitude;

            obj.toggelWobbleParamListeners(true)
            obj.wavelength=lastWobble.wavelength; %So this triggers make wobble model
        end

        function writeWobbleParams(obj)
            % Writes current wobble parameters to a mat file for later re-use
            lastWobble.phase = obj.phase;
            lastWobble.amplitude = obj.amplitude;
            lastWobble.wavelength = obj.wavelength;

            SETTINGS_DIR = strrep(which('wobbleRemover'), '@wobbleRemover/wobbleRemover.m','settingsWobbleRemover');
            fname = fullfile(SETTINGS_DIR,obj.paramsFname);
            save(fname,'lastWobble')
        end


        % The following are listeners that run when certain properties are updated
        function plotWobbleLine(obj,~,~)
            % Runs when wobble line changes
            obj.hWobble.YData = obj.wobbleModel.wobble + size(obj.originalImage,1)/2;
            obj.hWobble.XData = 1:length(obj.wobbleModel.zVals);
        end % plotWobbleLine


        function runImageCorrection(obj,~,~)
            % Run correction on the single slice in obj.originalImage
            %RUN CORRECTION
            for ii=1:length(obj.wobbleModel.wobble)
                tWobble = round(obj.wobbleModel.wobble(ii)) * -1;
                obj.correctedImage(:,ii) = circshift(obj.originalImage(:,ii), tWobble);
            end
            % Use the current parameters to correct the full stack
            obj.hCorrectedIm.CData = obj.correctedImage;
        end % runImageCorrection
    end % methods


end %classdef