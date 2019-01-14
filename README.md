# mesoSPIMmat

This repository contains tools for handling mesoSPIM data in MATLAB.

## Contents
* raw data file reader
* bare-bones de-wobbler for parasitic motion of z-stage


## De-wobbler
Some of the original mesoSPIMs have z-drives which translate side to side ("wobble") as they move in z. 
This originates from play in the lead-screw and should have a period of 500 microns.
The amplitude and phase will vary from system to system but should be consistent within a system from run to run. 
This tool models the error as a sine wave and cancels it out.

The tool works manually, so the user must play with the parameters to get an acceptable effect.
The tool is currently a very early version and hardly tested. 
To use:

```
% Load the file as follows:
>> W = wobbleRemove('MyFile.raw');

% You can also load the file separately then feed it to the tool
>> data = mesotools.rawReader('MyFile.raw'); 
>> W = wobbleRemove(data);
```

You will now see a view showing the original image on the left and the corrected image on the right.
The sine wave representing the wobble is overlaid on the right image. 
You can choose a different plane to view by changing the value of the `slicePlane` property:

```
% To view slice 300
>> W.slicePlane=300;
```
You can alter amplitude, phase, or wavelength with the sliders or by modifying the following fields:
```
W.amplitude  % Currently in pixels (see below)
W.phase      % With respect to z=0
W.wavelength % Likely shouldn't need much tweaking
```

When you're happy you can save the data:
```
>> W.saveData % Creates a new file with "_DEWOBBLE" appended to the name
% OR
>> W.saveData(true)Over-write original (DANGEROUS!)
```

Running the tool with no input arguments will bring up a basic demo dataset. 

### Results
The following two images were obtained from the same stack and illustrate the sort of improvement you can expect after about 5 minutes of tweaking. 
There is still room for improvement, but it's vastly better than the raw data.
The lightsheet was made very thick by adding a large offset to the ETL amplitude in order to amplify the effect of wobble from the Z stage (since it makes the same structure visible over a large number of z-planes). 
<img src="https://github.com/mesoSPIM/mesoSPIMmat/wiki/images/wobble1.png" />
<img src="https://github.com/mesoSPIM/mesoSPIMmat/wiki/images/wobble2.png" />

Further work is likely needed to come up with ways to derive the parameters automatically, to assist in the search, or to constrain them substantially somehow.


### Known issues
* The number of microns per pixel is hard-coded as "1" and so the amplitude of the wobble line is in pixels not microns
