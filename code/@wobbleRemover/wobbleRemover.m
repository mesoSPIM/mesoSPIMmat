classdef wobbleRemover < handle
    % wobbleRemover is a class for interactively getting rid of parasitic X motion artifacts in mesoSPIM z-stacks


    % TODO: if the other re-slice also shows oscillation then this would mean that the 
    %       oscillation is some sort of squashed helix and we will need to correct it in both
    %       dimensions. 



    properties (SetObservable)
        % wobble model parameters
        phase=0         % phase of the wobble with respect to the start of the stack
        amplitude=20    % amplitude in microns %TODO: currently this is in pixels
        wavelength=500  % wavelength of the oscillation in microns
        wobbleOffset=0; % the start of the stack in z, so we will be able to apply the parameters across stacks

        slicePlane % The index of the plane to plot
    end % properties (SetObservable)


    properties
        hFig
        hOrigAx      % Axis of original image 
        hCorrectedAx % Axis of corrected image
        hOrigIm      % Handle to image object for original image
        hCorrectedIm % Handle to image object for corrected image
        hWobble     %  Handle of the guide line showing the wobble we are modeling

        imData      % The full stack and associated meta-data (see mesotools.rawReader)
    end % properties


    properties (Hidden,SetObservable)
        wobbleModel %This is the sine wave that models the wobble
        wobbleParamGUI
    end % properties (Hidden,SetObservable)


    properties (Hidden)
        paramsFname = 'lastGoodWobbleParams.mat' %Last known good parameters are stored in this fname in the "settings" directory
        listeners = {}             % cell array containing various listeners for making the GUI work
        wobbleParamListeners = {}  % listeners for updating plot elements when a wobble parameter is modified
        simulatedMode=false        % true if running in simulated mode
    end % properties (Hidden)



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
            % NOTE: run without input arguments for simulated mode. Used for development.
            %
            %
            % Rob Campbell - SWC 2019


            % handle input arguments
            if nargin<1
                % Set up simulated mode if run without input arguments
                fprintf(' \nRUNNING WOBBLEREMOVER WITH DUMMY DATASET\n\n ')
                obj.simulatedMode=true;

                obj.imData  = obj.generateTestingImage;

                % Make the artifact more obvious
                obj.amplitude=10; 
                obj.wavelength=250;

            else
                % Either read from file name or run with supplied data:
                % If fname is a file name, the stack is read. If it's a structure, it's treated as 
                % being the output of mesotools.rawReader
                if ischar(fname)
                    obj.imData = mesotools.rawReader(fname);
                elseif isstruct(fname)
                    obj.imData = fname;
                elseif isempty(obj.imData)
                    return
                end
            end


            % We may get unexpected behavior if the user has loaded a subset of frames, so block this
            if size(obj.imData.imStack,3) ~= obj.imData.POSTION.z_planes
                fprintf('Image stack seems to be missing frames. wobbleRemover will not proceed.\n')
                delete(obj)
                return
            end


            % Prepare to set up the figure window: close any existing wobbleRemover windows
            delete(findobj('Name','wobbleRemover'))
            delete(findobj('Name','wobble parameters'))


            % Set up the figure window
            obj.hFig = clf;
            obj.hFig.Name='wobbleRemover';
            obj.slicePlane=round(size(obj.imData.imStack,3)/2);

            obj.hOrigAx = subplot(1,2,1);
            obj.hOrigIm = imagesc( squeeze(obj.imData.imStack(:,obj.slicePlane,:)) );
            hold on
            obj.hWobble = plot(nan,nan,'-r');
            obj.hOrigAx = gca;
            title('Original image')
            axis off

            obj.hCorrectedAx = subplot(1,2,2);
            obj.hCorrectedIm = imagesc( squeeze(obj.imData.imStack(:,obj.slicePlane,:)) );
            obj.hCorrectedAx = gca;
            title('Corrected image')
            axis off

            colormap gray

            obj.hFig.CloseRequestFcn = @obj.figClose; %Closing figure deletes object


            if obj.readWobbleParams %If the file is there then we must have successfully ran the correction
                %Pass - the model will update and make the line
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


            if obj.simulatedMode
                % We are in simulated mode then we want to apply a wobble *to* the original stack
                obj.correctStack(true); %true to not apply the inverse of the wobble
                obj.updatePlottedPlanes
            end


            % Add an extra GUI window containing sliders so we can easily set the wobble parameters
            obj.wobbleParamGUI = figure;
            obj.wobbleParamGUI.CloseRequestFcn = @obj.figClose; %Closing figure deletes object
            obj.wobbleParamGUI.Name='wobble parameters';
            obj.wobbleParamGUI.Resize = 'off';
            obj.wobbleParamGUI.MenuBar = 'none';
            figWidth=400;
            obj.wobbleParamGUI.Position(3)=figWidth;
            obj.wobbleParamGUI.Position(4)=100;
            obj.wobbleParamGUI.Position(2) = obj.hFig.Position(2)-obj.wobbleParamGUI.Position(4)-25;


            % build the sliders
            sliderL=35;
            obj.phase
            obj.wobbleParamGUI.UserData.phaseSlider = uicontrol('Parent',obj.wobbleParamGUI, 'Style', 'slider','Position',[sliderL,54,figWidth-35,23],...
              'value', obj.phase, 'min',-pi-1, 'max', pi+1, 'SliderStep', [0.0005,0.05]);
            obj.wobbleParamGUI.UserData.phaseText = uicontrol('Parent',obj.wobbleParamGUI, 'Style', 'Text','Position',[3,53,sliderL-2,30],...
                'String', sprintf('%0.3f',obj.phase));

           obj.wobbleParamGUI.UserData.wavelengthSlider = uicontrol('Parent',obj.wobbleParamGUI, 'Style', 'slider','Position',[sliderL,29,figWidth-35,23],...
              'value', obj.wavelength, 'min',obj.wavelength-50, 'max', obj.wavelength+50);
            obj.wobbleParamGUI.UserData.wavelengthText = uicontrol('Parent',obj.wobbleParamGUI, 'Style', 'Text','Position',[3,29,sliderL-2,25],...
                'String', sprintf('%d',obj.wavelength));

            obj.wobbleParamGUI.UserData.amplitudeSlider = uicontrol('Parent',obj.wobbleParamGUI, 'Style', 'slider','Position',[sliderL,4,figWidth-35,23],...
              'value', obj.amplitude, 'min',0, 'max', 40, 'SliderStep', [0.0015,0.05]);
            obj.wobbleParamGUI.UserData.amplitudeText = uicontrol('Parent',obj.wobbleParamGUI, 'Style', 'Text','Position',[3,4,sliderL-2,25],...
                'String', sprintf('%0.2f',obj.amplitude));

 
            % Set up "pre-set" listeners so the plots update during slider action, not after
            obj.listeners{end+1} = addlistener(obj.wobbleParamGUI.UserData.phaseSlider, 'Value', 'PreSet',@obj.updatePhaseFromGUI);
            obj.listeners{end+1} = addlistener(obj.wobbleParamGUI.UserData.amplitudeSlider, 'Value', 'PreSet',@obj.updateAmplitudeFromGUI);
            obj.listeners{end+1} = addlistener(obj.wobbleParamGUI.UserData.wavelengthSlider, 'Value', 'PreSet',@obj.updateWavelengthFromGUI);
        end % wobbleRemover


        %DESTRUCTOR
        function delete(obj)
            cellfun(@delete,obj.listeners)
            cellfun(@delete,obj.wobbleParamListeners)

            delete(obj.wobbleParamGUI)
            delete(obj.hFig) %close figure
        end % delete




        % ------------------------------------------------------------------
        function updatePlottedPlanes(obj,~,~)
            % Refresh the original image and re-run the correction and plot the corrected image
            obj.hOrigIm.CData = squeeze(obj.imData.imStack(:,obj.slicePlane,:));
            obj.plotWobbleLine
            obj.runImageCorrection;
        end


        function plotWobbleLine(obj,~,~)
            % Runs when wobble line changes
            obj.hWobble.YData = obj.wobbleModel.wobble + size(obj.hOrigIm.CData,1)/2;
            obj.hWobble.XData = 1:length(obj.wobbleModel.zVals);
        end % plotWobbleLine


        function runImageCorrection(obj,~,~)
            % Run correction on the single displayed slice

            for ii=1:length(obj.wobbleModel.wobble)
                tWobble = round(obj.wobbleModel.wobble(ii)) * -1;
                obj.hCorrectedIm.CData(:,ii) = circshift(obj.hOrigIm.CData(:,ii), tWobble);
            end
        end % runImageCorrection

    end % main methods block


    % The following house-keeping methods are hidden from the user
    methods (Hidden)

        function updatePhaseFromGUI(obj,~,~)
            obj.phase=obj.wobbleParamGUI.UserData.phaseSlider.Value;
            obj.wobbleParamGUI.UserData.phaseText.String = sprintf('%0.3f',obj.phase);
        end

        function updateAmplitudeFromGUI(obj,~,~)
            obj.amplitude=obj.wobbleParamGUI.UserData.amplitudeSlider.Value;
            obj.wobbleParamGUI.UserData.amplitudeText.String = sprintf('%0.2f',obj.amplitude);
        end

        function updateWavelengthFromGUI(obj,~,~)
            obj.wavelength=round(obj.wobbleParamGUI.UserData.wavelengthSlider.Value);
            obj.wobbleParamGUI.UserData.wavelengthText.String = sprintf('%d',obj.wavelength);
        end


        function toggleWobbleParamListeners(obj,enableDisableBool)
            % Used to disable wobble param listeners before the parameters are updated from disk
            % Probably this is overkill but let's be near for now
            % input arg should be true/false
            for ii=1:length(obj.wobbleParamListeners)
                obj.wobbleParamListeners{ii}.Enabled = enableDisableBool;
            end
        end

        function figClose(obj,~,~)
            % Figure close function: figures are destroyed in the destructor
            obj.delete %class destructor
        end

    end % hidden house-keeping methods


    % Getters/setters
    methods
        function set.slicePlane(obj,inArg)
            if inArg<1 
                fprintf('Value out of range for imStack\n')
            elseif inArg>size(obj.imData.imStack,3)
                fprintf('Value out of range for imStack, which has %d planes\n',size(obj.imData.imStack,3))                
            else
                obj.slicePlane = inArg;
            end
        end % set.slicePlane
    end %getters/setters

end %classdef

