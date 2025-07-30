function [h, txt] = rangeAddFixed(spec, colorScheme, manualName, rangeLimits, rangeWidth)
% Adds a fixed-width range to a mass spectrum using a single click for center
%
% INPUT
% spec:         area plot displaying the mass spectrum (histogram of m/z)
% colorScheme:  table with elements assigned to color code
% manualName:   name of range if no ion is defined (optional)
% rangeLimits:  2-element vector to define center, overrides click (optional)
% rangeWidth:   numeric value defining width of range (optional)
%
% OUTPUT
% h:    handle to the area plot of the range
% txt:  corresponding label

%% Set default width
if ~exist('rangeWidth', 'var') || isempty(rangeWidth)
    rangeWidth = 0.5; % default width in m/z
end

ax = spec.Parent;
axes(ax);

%% Define range limits
if ~exist('rangeLimits', 'var') || isempty(rangeLimits)
    [x, ~, mbIdx] = ginput(1); % Single click for center
    if mbIdx == 3
        h = [];
        txt = [''];
        return
    end
    lim = [x - rangeWidth/2; x + rangeWidth/2];
else
    center = mean(rangeLimits);
    lim = [center - rangeWidth/2; center + rangeWidth/2];
end

lim = sort(lim);

%% Check for overlap with existing ranges
plots = spec.Parent.Children;
for pl = 1:length(plots)
    try
        type = plots(pl).UserData.plotType;
    catch
        type = "unknown";
    end
    if type == "range"
        existingLim = [plots(pl).XData(1), plots(pl).XData(end)];

        if lim(1) > existingLim(1) && lim(2) < existingLim(2)
            error('Total overlap with existing range.');
        elseif lim(1) < existingLim(1) && lim(2) > existingLim(2)
            error('New range completely covers an existing range.');
        elseif lim(1) < existingLim(2) && lim(2) > existingLim(2)
            lim(1) = existingLim(2) + (spec.XData(end) - spec.XData(end-1));
            msgbox({'Partial overlap: new range was clipped.'}, 'Notification');
        elseif lim(1) < existingLim(1) && lim(2) > existingLim(1)
            lim(2) = existingLim(1) - (spec.XData(end) - spec.XData(end-1));
            msgbox({'Partial overlap: new range was clipped.'}, 'Notification');
        end
    end
end

if lim(1) == lim(2)
    error('Invalid range width or overlap. Try again.');
end

%% Create range plot
isIn = (spec.XData > lim(1)) & (spec.XData < lim(2));
h = area(spec.XData(isIn), spec.YData(isIn));
h.FaceColor = [1 1 1];
h.UserData.plotType = "range";

%% Handle manual range name
isManual = exist('manualName', 'var') && ~isempty(manualName);
isBackground = isManual && strcmp(manualName, 'background');
isValidIonName = false;

if isManual && ~isBackground
    [ion, chargeState] = ionConvertName(manualName);
    if ~isnan(chargeState) && ~any(isnan(ion.isotope))
        isValidIonName = true;
    end

    if ~isnan(chargeState)
        h.UserData.ion = ion;
        h.UserData.chargeState = chargeState;
        h.DisplayName = ionConvertName(ion, chargeState);
        color = colorScheme.color(colorScheme.ion == ionConvertName(ion.element), :);
    else
        h.UserData.ion = manualName;
        h.UserData.chargeState = NaN;
        h.DisplayName = manualName;
        color = colorScheme.color(colorScheme.ion == manualName, :);
    end

    if isempty(color)
        name = h.DisplayName;
        delete(h);
        error(['Color for atom/ion ' name ' undefined']);
    end

    h.FaceColor = color;

elseif isManual && isBackground
    h.UserData.plotType = "background";
    h.DisplayName = "background";
    h.FaceColor = colorScheme.color(colorScheme.ion == 'background', :);
end

%% Try automatic ion detection (if no manualName)
if ~isManual
    plots = ax.Children;
    isIon = false(length(plots),1);
    for pl = 1:length(plots)
        try
            isIon(pl) = strcmp(plots(pl).UserData.plotType,"ion");
        end
    end
    ionPlots = plots(isIon);

    potentialIon = {};
    potentialIonChargeState = [];
    potentialIonPeakHeight = [];

    for pl = 1:length(ionPlots)
        inRange = (ionPlots(pl).XData > lim(1)) & (ionPlots(pl).XData < lim(2));
        if any(inRange)
            peakIdx = find((ionPlots(pl).YData == max(ionPlots(pl).YData(inRange))) & inRange);
            potentialIon{end+1} = ionPlots(pl).UserData.ion{peakIdx};
            if isscalar(ionPlots(pl).UserData.chargeState)
                potentialIonChargeState(end+1) = ionPlots(pl).UserData.chargeState;
            else
                potentialIonChargeState(end+1) = ionPlots(pl).UserData.chargeState(peakIdx);
            end
            potentialIonPeakHeight(end+1) = ionPlots(pl).YData(peakIdx);
        end
    end

    if isempty(potentialIon)
        delete(h);
        error('No ion found in this range. Please specify a name manually.');
    else
        [~, maxIdx] = max(potentialIonPeakHeight);
        h.UserData.ion = potentialIon{maxIdx};
        h.UserData.chargeState = potentialIonChargeState(maxIdx);
        h.DisplayName = ionConvertName(h.UserData.ion, h.UserData.chargeState);
    end
end

%% Assign color
if isManual && sum(colorScheme.ion == manualName) == 1
    h.FaceColor = colorScheme.color(colorScheme.ion == manualName, :);
elseif sum(colorScheme.ion == ionConvertName(h.UserData.ion.element)) == 1
    h.FaceColor = colorScheme.color(colorScheme.ion == ionConvertName(h.UserData.ion.element), :);
else
    delete(h);
    error('This ion does not exist in the colorScheme. Please add it using colorSchemeIonAdd().');
end

h.UserData.hitMultiplicities = [0 Inf];

%% Add label
if ~isBackground
    if isManual && ~isValidIonName
        txt = text(h.XData(1), max(h.YData)*1.4, manualName, 'clipping', 'on');
        txt.DisplayName = manualName;
    else
        txt = text(h.XData(1), max(h.YData)*1.4, ...
            ionConvertName(h.UserData.ion, h.UserData.chargeState, 'LaTeX'), ...
            'clipping', 'on');
        txt.DisplayName = ionConvertName(h.UserData.ion, h.UserData.chargeState, 'plain');
    end
    txt.UserData.plotType = "text";
    h.DeleteFcn = @(~,~) delete(txt);
else
    txt = [];
end
end
