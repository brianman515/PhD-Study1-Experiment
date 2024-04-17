pupil_left = zeros(length(gaze_data),1);
pupil_right = zeros(length(gaze_data),1);
for ii = 1:size(gaze_data,1)
    pupil_left(ii,1) = gaze_data(ii,1).LeftEye.Pupil.Diameter;
    pupil_right(ii,1) = gaze_data(ii,1).RightEye.Pupil.Diameter;
end

%LP Window
Param.fs = 60;
Param.RemoveBeforeandAfter = [35 100]*1e-3;
Param.MinLengthNaNrepair = 1;
Param.LPWinSize = 1;

RawDiameter = pupil_right;
L = length(pupil_right);

Metadata.time = ((0:(L-1))/Param.fs)';
Metadata.IsnanRaw = isnan(RawDiameter);
Metadata.IntactRaw = ~Metadata.IsnanRaw;

if isnan(nan)
    VinX = isnan(RawDiameter);
else
    VinX = RawDiameter; 
end

DiffVinX = [diff([0;VinX])];
BegEndIdx = [find(VinX & DiffVinX) find(VinX & [DiffVinX(2:end); -1] == -1)];
Metadata.ContigNaN = BegEndIdx;

LengthCongtigNan = diff(Metadata.ContigNaN,1,2);
RemoveContigNan = Metadata.ContigNaN(find(LengthCongtigNan >= Param.MinLengthNaNrepair),:);

RemoveContigNan(:,1) = RemoveContigNan(:,1) - ceil(Param.RemoveBeforeandAfter(1)*Param.fs);
RemoveContigNan(:,2) = RemoveContigNan(:,2) - ceil(Param.RemoveBeforeandAfter(2)*Param.fs);

RemoveContigNan = max(RemoveContigNan,1);
RemoveContigNan = min(RemoveContigNan,length(RawDiameter));

Diameter = RawDiameter;
for idx = 1:size(RemoveContigNan,1)
    Diameter(RemoveContigNan(idx,1):RemoveContigNan(idx,2)) = nan;
end

Metadata.Isnan = isnan(Diameter);
Metadata.Intact = ~Metadata.isnan;

if sum(Metadata.Intact) > 1
    Diameter(Metadata.Isnan) = interp1(Metadata.time(Metadata.Intact),Diameter(Metadata.Intact),Metadata.Time(Metadata.Isnan));

    if isnan(nan)
        VinX = isnan(RawDiameter);
    else
        VinX = RawDiameter; 
    end

    EdgeNaNs = BegEndIdx;
    for idx = 1:size(EdgeNaNs,1)
        if EdgeNaNs(idx,1) == 1
            Diameter(EdgeNaNs)
    end

DiffVinX = [diff([0;VinX])];
BegEndIdx = [find(VinX & DiffVinX) find(VinX & [DiffVinX(2:end); -1] == -1)];
Metadata.ContigNaN = BegEndIdx;


LPWindow = hamming(round(Param.LPWinSize*Param.fs));
LPWindow = LPWindow/sum(LPWindow);

Diameter_LP_L = conv(pupil_left,LPWindow,'same');
Diameter_LP_R = conv(pupil_right,LPWindow,'same');