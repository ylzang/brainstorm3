function F = in_fread_nwb(sFile, SamplesBounds, selectedChannels)
% IN_FREAD_INTAN Read a block of recordings from nwb files
%
% USAGE:  F = in_fread_nwb(sFile, SamplesBounds=[], iChannels=[])

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Author: Konstantinos Nasiotis 2019


% Parse inputs
if (nargin < 3) || isempty(selectedChannels)
    selectedChannels = 1:length(sFile.channelflag);
end
if (nargin < 2) || isempty(SamplesBounds)
    SamplesBounds = sFile.prop.samples;
end

nChannels = length(selectedChannels);
nSamples = SamplesBounds(2) - SamplesBounds(1) + 1;

timeBounds = SamplesBounds./sFile.prop.sfreq;


%% Load the nwbFile object that holds the info of the .nwb
nwb2 = sFile.header.nwb; % Having the header saved, saves a ton of time instead of reading the .nwb from scratch


nEEGChannels        = sum(strcmp(sFile.header.ChannelType,'EEG'));

allBehaviorKeys = sFile.header.ChannelType;
%% Get the signals

% HERE THE ASSUMPTION IS THAT THE LABELING OF THE CHANNELS HAS NOT CHANGED
% FROM WHAT THE IMPORTER POPULATED
% This could lead to problems

F = zeros(nChannels, nSamples);

% Get the Intracranial signals
iEEG = 0;
for iChannel = 1:nChannels
    if strcmp(sFile.header.ChannelType{selectedChannels(iChannel)}, 'EEG') 
        iEEG = iEEG + 1;
        F(iChannel,:) = nwb2.processing.get('ecephys').nwbdatainterface.get('LFP').electricalseries.get(sFile.header.LFPKey).data.load([selectedChannels(iEEG), SamplesBounds(1)+1], [selectedChannels(iEEG), SamplesBounds(2)+1]);
    
    else
        % Get the additional/behavioral channels
        if ~isempty(sFile.header.allBehaviorKeys)
            position_timestamps =  nwb2.processing.get('behavior').nwbdatainterface.get(allBehaviorKeys{iChannel,1}).spatialseries.get(allBehaviorKeys{iChannel,2}).timestamps.load; % I use only the first subkey - subkeys should have the same timestamps
            % Get the indices of the samples that are within the time-selection
            selected_timestamps = find(position_timestamps>timeBounds(1) & position_timestamps<timeBounds(2));


            if length(selected_timestamps)<2 % There is not a start and a stop sample present at least
                F(iChannel,:) = nan(1, nSamples);
                disp(['Time selection is outside the timestamps for the ' allBehaviorKeys{iChannel,1} ' channels'])
            else

                selected_timestamps_bounds = [selected_timestamps(1) selected_timestamps(end)];

                % These Behavioral channels have different sampling rates -
                % they need to be upsampled
                % Moreover, there are multiple channels within each
                % Behavioral description                
                iAdditionalChannel = find(find(strcmp(allBehaviorKeys(:,2), allBehaviorKeys{iChannel,2}))==iChannel); % This gives the index of the channel selected with the behavior channels
                
                temp = nwb2.processing.get('behavior').nwbdatainterface.get(allBehaviorKeys{iChannel,1}).spatialseries.get(allBehaviorKeys{iChannel,2}).data.load([iAdditionalChannel, selected_timestamps_bounds(1)], [iAdditionalChannel, selected_timestamps_bounds(2)]);
                temp = temp(~isnan(temp)); % Some entries might be nans
                
                upsampled_position = interp(temp,ceil(nSamples/length(temp)));

                logical_keep = true(1,length(upsampled_position));
                random_points_to_remove = randperm(length(upsampled_position),length(upsampled_position)-nSamples);
                logical_keep(random_points_to_remove) = false;

                F(iChannel,:) = upsampled_position(logical_keep);
            end

        end
    end
end



end
