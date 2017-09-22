%
% Event Analyser
%
% EvA_extract.m
%
% Johannes Hjorth
% Julia Dawitz
% Rhiannon Meredith
% 
% For questions contact: Johanes Hjorth, hjorth@kth.se
% Julia Dawitz: julia.dawitz@vu.nl
% Rhiannon Meredith: r.m.meredith@vu.nl
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function EvA_extractMorphology()

  version = '2017-09-25';

  %%% Set up the windows 
  data.img = [];
  data.xRes = 0.7;
  data.yRes = 0.7;
  data.zRes = 1;
  data.freq = 10;

  data.piaDist = [];
  data.piaPosition = [];

  % Parameters used for plotting
  img.showZ = 1;
  img.intensityLow = 0;
  img.intensityHigh = 1;
  img.histAxis = [0 1 0 1];
  img.isPlotted = 0;
  img.showPutativeCenters = 1;
  img.showGrid = 1;

  editInfo.undo = {};
  editInfo.undoIdx = 0;
  editInfo.actionType = {};
  editInfo.mouseEditMode = 0;


  % Here remove 90% of lowest pixel values for putative neuron detection
  detection.putativeThreshold = 0.925;

  % Should we use auto threshold or not?
  detection.autoThreshold = 0;

  % Ignore local maxima that have a larger local maxima closer than 
  % this number of pixels
  detection.minNeuronDist = 11;

  % In addition to looking for local maxima in the center plane
  % we also look for local minima in the frames +/- 5 micrometers 
  % in the Z direction
  detection.Zspacing = 5;
  detection.useZspacing = 0; %1;
 
  % Pre-smoothing for center detection
  detection.smoothing = 3;
  detection.useBGremoval = 1;

  % Require the neuron to have a volume in the range
  % Radii, 4-20 micrometers (volume in unit of micrometers^3)
  detection.minVolume = 4*pi*(2)^3/3;
  detection.maxVolume = 4*pi*(10)^3/3;

  % How do we vary the threshold when looking for neuron edge
  detection.minEdgeThresh = 1 %0.5;
  detection.maxEdgeThresh = NaN; % Autodetect if NaN. 0.7;
  detection.nEdgeSteps = 15;

  % There will be nVert*nVert vertexes used for sphere
  % and each vertexes will have nGrid possible locations
  detection.nVert = 15;
  detection.nGrid = 20;

  % Require that the neuron is at least 16 square micrometers in center plane
  detection.minPlaneArea = 25;

  % Maximal radii within the neuron must be located
  detection.maxR = 20;

  % Minimum size of a neuron (in pixels)
  detection.minSize = 5;
 
  detection.done = 0;

  % Save all values so we can restore them later if the user wants
  defaultDetection = detection;

  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  configFile = 'EvA_config_for_extract.mat';
  
  saveDataPars = {'xRes','yRes','zRes','freq'};
  saveImgPars = {'showGrid'};
  saveDetectionPars = {'putativeThreshold','autoThreshold', ...
                      'minNeuronDist','Zspacing','useZspacing', ...
                      'smoothing','useBGremoval', ...
                      'minVolume','maxVolume',...
                      'minEdgeThresh','maxEdgeThresh','nEdgeSteps',...
                      'nVert', 'nGrid', 'minPlaneArea', 'maxR', ...
                      'minSize'};
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  % End of parameter intialisation
  
  % Load previously saved config values
  loadConfig();
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  close all
  handles.fig = figure('Name', ...
                       'Event Analyser (EvA) - Extract Morphology', ...
                       'MenuBar','none', ...
                       'Toolbar', 'figure', ...
                       'WindowButtonDownFcn', ...
                       @MouseButtonDownHandler, ...
                       'Position', [50 50 1130 630]);

  % This window shows the slice with neurons marked out
  handles.plotLeft     = axes('Units','Pixels', ...
                              'Position',[30 110 500 500]);
  axis off

  % This panel shows the histogram, to select intensity for plot
  handles.hist         = axes('Units','Pixels', ...
			      'Position',[560 30 500 50]);
  axis off

  % This panel shows the raw image
  handles.plotRight    = axes('Units','Pixels', ...
			      'Position',[560 110 500 500]);
  axis off


  % This is used to select which z-depth to show of the stack
  handles.zSlider = uicontrol('Style','slider','Max',1,'Min',0, ...
			      'Visible','off', ...
			      'Position',[1080,110,25,460], ...
			      'Value', img.showZ, ...
			      'Interruptible', 'off', ...
			      'Callback', @setzSlider);

  handles.zText   = uicontrol('Style','edit', ...
			      'String', num2str(img.showZ), ...
			      'Visible','off', ...
			      'Position', [1080 585 25 25], ...
			      'Interruptible', 'off', ...
			      'Callback', @setzText);

  handles.histText = uicontrol('Style','text', ...
			       'String', ...
			       'Image intensity histogram:', ...
			       'HorizontalAlignment', 'left', ...
			       'Backgroundcolor',0.8*[1 1 1], ...
			       'Visible','off', ...
			       'Position', [560 85 200 15]);

  handles.threshText = ...
    uicontrol('Style','text', ...
	      'String', ...
	      sprintf('Threshold for center detection: %.3f', ...
		      detection.putativeThreshold), ...
	      'HorizontalAlignment', 'left', ...
	      'Backgroundcolor',0.8*[1 1 1], ...
	      'Visible','off', ...
	      'Position', [30 85 300 15]);


  handles.centerThresh = uicontrol('Style','slider','Max',1,'Min',1e-4, ...
				   'Position',[30,60,500,20], ...
				   'Visible','off', ...
				   'Value', detection.putativeThreshold, ...
				   'Interruptible', 'off', ...
				   'Callback', @setPutativeThresholdSlider);

  handles.Ztext = uicontrol('Style', 'text', ...
			    'String', ...
			    sprintf('Include frames +/-%d of Z-center', ...
				    detection.Zspacing), ...
			    'HorizontalAlignment', 'left', ...
			    'Backgroundcolor',0.8*[1 1 1], ...
			    'Visible','off', ...
			    'Position', [245 35 280 15]);

  handles.includeZdepth = uicontrol('Style', 'Checkbox', ...
				    'Value', detection.useZspacing, ...
				    'Min', 0, 'Max', 1, ...
				    'Position', [220 35 15 15], ...
				    'Visible', 'off', ...
				    'Interruptible', 'off', ...
				    'Callback', @toggleIncludeZdepth);

  handles.BGtext = uicontrol('Style', 'text', ...
			     'String', 'Use background removal', ...
			     'HorizontalAlignment', 'left', ...
			     'Backgroundcolor',0.8*[1 1 1], ...
			     'Visible','off', ...
			     'Position', [245 20 280 15]);


  handles.useBGremoval = uicontrol('Style', 'Checkbox', ...
				   'Value', detection.useBGremoval, ...
				   'Min', 0, 'Max', 1, ...
				   'Position', [220 20 15 15], ...
				   'Visible', 'off', ...
				   'Interruptible', 'off', ...
				   'Callback', @toggleUseBGremoval);


  handles.edgeText = ...
    uicontrol('Style','text', ...
	      'String', ...
	      sprintf('Lower threshold for edge detection: %.3f', ...
		      detection.minEdgeThresh), ...
	      'HorizontalAlignment', 'left', ...
	      'Backgroundcolor',0.8*[1 1 1], ...
	      'Visible','off', ...
	      'Position', [30 85 300 15]);


  handles.edgeMinThresh = uicontrol('Style','slider','Max',1,'Min',0, ...
				   'Position',[30,60,500,20], ...
				   'Visible','off', ...
				   'Value', detection.minEdgeThresh, ...
				   'Interruptible', 'off', ...
				   'Callback', @setMinEdgeThresholdSlider);


  handles.detectEdges = uicontrol('Style', 'pushbutton', ...
				  'String', 'Detect edges', ...
				  'Position', [30 20 150 30], ...
				  'Visible','off', ...
				  'Interruptible', 'off', ...
				  'Callback', @detectEdgesButton);

  handles.markPia = uicontrol('Style', 'pushbutton', ...
			      'String', 'Mark pia', ...
			      'Position', [190 20 150 30], ...
			      'Visible','off', ...
			      'Interruptible', 'off', ...
			      'Callback', @markPia);

  handles.splitNeurons = uicontrol('Style', 'pushbutton', ...
				   'String', 'Split neurons', ...
				   'Position', [350 20 150 30], ...
				   'Visible','off', ...
				   'Interruptible', 'off', ...
				   'Callback', @splitNeurons);


  handles.defineROI = uicontrol('Style', 'pushbutton', ...
				'String', 'Define ROI', ...
				'Position', [450 20 80 30], ...
				'Visible','off', ...
				'Interruptible', 'off', ...
				'Callback', @defineRegionOfInterest);


  handles.credits = uicontrol('Style', 'text', ...
			      'String', ...
			      'Johannes Hjorth, Julia Dawitz, Rhiannon Meredith 2010', ...
			      'HorizontalAlignment', 'right', ...
			      'Foregroundcolor', 0.7*[1 1 1], ...
			      'Backgroundcolor', get(gcf,'color'), ...
			      'Position', [815 5 310 15], ...
			      'Fontsize',8);


set([handles.fig, handles.plotLeft, handles.hist, handles.plotRight, ...
     handles.zSlider, handles.zText, handles.histText, handles.threshText, ...
     handles.centerThresh, handles.Ztext, handles.includeZdepth, ...
     handles.BGtext, handles.useBGremoval, handles.edgeText, ....
     handles.defineROI, handles.markPia, handles.splitNeurons, ...
     handles.edgeMinThresh, handles.detectEdges, handles.credits], ...
    'Units','Normalized')

  % Load and save menu item
  handles.menuFile     = uimenu(handles.fig,'Label','File');
  handles.menuItemLoad = uimenu(handles.menuFile,'Label','Load Z-stack', ...
				'Interruptible', 'off', ...
				'Callback', @loadTiffStack);
  handles.menuItemSave = [];
  handles.menuItemCorr = [];
  handles.importMask = [];


  % Settings menu
  handles.menuSettings  = uimenu(handles.fig,'Label','Settings');


  handles.menuItemCenterSetting  = uimenu(handles.menuSettings, ...
					  'Label','Center detection', ...
					  'Interruptible', 'off', ...
					  'Callback', ...
					  @changeCenterDetectionSettings);

  handles.menuItemEdgeAuto = uimenu(handles.menuSettings, ...
				    'Label', 'Auto edge threshold', ...
				    'Interruptible', 'off', ...
				    'Checked', 'on', ...
				    'Callback', @toggleAutoEdge);

  if(detection.autoThreshold)
    set(handles.menuItemEdgeAuto,'Checked','on');
  else
    set(handles.menuItemEdgeAuto,'Checked','off');
  end

  handles.menuItemEdgeSetting  = uimenu(handles.menuSettings, ...
					'Label','Edge detection', ...
					'Interruptible', 'off', ...
					'Callback', ...
					@changeEdgeDetectionSettings);

  handles.menuItemResolution = uimenu(handles.menuSettings, ...
				      'Label','Image resolution', ...
				      'Interruptible', 'off', ...
				      'Callback', ...
				      @changeImageResolutionSettings);

  handles.toggleGrid         = uimenu(handles.menuSettings, ...
				      'Label', 'Display grid', ...
				      'Interruptible', 'off', ...
				      'Callback', @toggleGrid);

  handles.resetSettings = uimenu(handles.menuSettings, ...
				 'Label', 'Reset settings', ...
				 'Interruptible', 'off', ...
				 'Callback', @resetSettings);

  if(img.showGrid)
    set(handles.toggleGrid,'Checked','on');
  else
    set(handles.toggleGrid,'Checked','off');
  end

  % Edit menu
  handles.menuEdit           = uimenu(handles.fig,'Label','Edit');
  handles.menuItemUndo       = uimenu(handles.menuEdit, ...
                                      'Label','No actions to undo', ...
                                      'Interruptible', 'off', ...
                                      'Callback', ...
                                      @undoAction);
  handles.menuItemPia = uimenu(handles.menuEdit, ...
                               'Label', 'Mark Pia', ...
                               'Interruptible', 'off', ...
                               'Callback', ...
                               @markPia);

  % Debug menu
  handles.menuDebug = uimenu(handles.fig,'Label','Debug');
  handles.menuItemDebug =  uimenu(handles.menuDebug, ...
				      'Label','Keyboard', ...
				      'Interruptible', 'off', ...
				      'Callback', @runDebug);


  % Menu for right clicking on slice after edge detection
  handles.modifyNeurons = uicontextmenu;

  uimenu(handles.modifyNeurons, ...
	 'Label', 'Add neuron',...
	 'Interruptible', 'off', ...
	 'Callback',@addNeuron3DCallback);
  uimenu(handles.modifyNeurons, ...
	 'Label', 'Delete neuron', ...
	 'Interruptible', 'off', ...
	 'Callback', @deleteNeuronCallback);
  uimenu(handles.modifyNeurons, ...
	 'Label', 'Add neuron (ROI)',...
	 'Interruptible', 'off', ...
	 'Callback',@addNeuronROI);


  % Some dirty tricks to get the zoom and pan tools
  % Set up toolbar, only keep zoom in, zoom out and pan
  handles.toolbar = findall(handles.fig,'Type','uitoolbar');
  oldChild = allchild(handles.toolbar);

  for i=1:length(oldChild)
    tmp = get(oldChild(i),'Tag');

    switch(tmp)
      case 'Exploration.ZoomIn';   
      case 'Exploration.ZoomOut';
      case 'Exploration.Pan';
      % Do nothing, we want to keep these
      otherwise 
      delete(oldChild(i));         % Remove the rest
    end
  end

  showPhoto();

%%% End of graphics initialisation %%%

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function showPhoto()

    urlRoot = 'http://www.johanneshjorth.se/files/EvA/';
    nPics = 1;

    % Matlabs random number generator gave the same number each time the first time
    % the program is run, so we also use the clock to get randomization.
    cTmp = clock();
    picNum = ceil(nPics*mod(rand + cTmp(end),1));
    logoName = sprintf('pics/logo%d.jpg', picNum);

    try
      %%% Load logo

      if(~exist('pics'))
        mkdir('pics');
      end
 
      if(~exist(logoName))
        % Logo image does not exist, download it from the web  
        [f,statusFlag] = urlwrite(strcat(urlRoot, logoName), logoName);

        if(~statusFlag)
          disp('Unable to download logo.')
        else
          disp(sprintf('Wrote %s', f))
        end
      end

      logoImg = imread(logoName);

      set(handles.fig,'CurrentAxes',handles.plotLeft)
      imshow(logoImg);


     %  wavload and wavplay

    catch
      % We end up here in case something failed above
      disp('Unable to load photo from webserver.')

      cachedPics = dir('pics/logo*jpg');

      % If there are cached pictures, choose one of them at random
      if(~isempty(cachedPics))
        idx = randperm(length(cachedPics));
        logoImg = imread(['pics/' cachedPics(idx(1)).name]);
        set(handles.fig,'CurrentAxes',handles.plotLeft)
        imshow(logoImg);
      end
    end
  end


%%% Callback functions for GUI %%%

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function runDebug(source, event)
    disp('Type return to exit debug mode')
    keyboard
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %%% Load tif-file

  function loadTiffStack(source, eventdata)

    % Ask the user for a tiff-file to read
    [tiffFile, tiffPath, fileType] = ...
	uigetfile({'*.tif','Select a tiff-file'; ...
		   '*.stk', 'Select stk file'});

    if(isequal(tiffFile,0) | isequal(tiffPath,0))
      % No file selected to load
      return
    end

    %%% Load the tiff-file %%%

    fileName = [tiffPath tiffFile];
    disp(sprintf('Loading %s', fileName))


    data.file = tiffFile;
    data.path = tiffPath;

    switch(fileType)
      case 1
        tiffInfo = imfinfo(fileName);

        data.height = tiffInfo(1).Height;
        data.width  = tiffInfo(1).Width; 
        data.Zdepth = length(tiffInfo);
        preloadStack = [];

      case 2

        preloadStack = tiffread(fileName);
        data.height = preloadStack(1).height;
        data.width = preloadStack(1).width;
        data.Zdepth = length(preloadStack);

      otherwise
        disp('Load error, talk to Johannes')
        keyboard
    end

    % data.img    = zeros(data.height,data.width,data.Zdepth,'single');
    data.img    = zeros(data.height,data.width,data.Zdepth);

    for i=1:data.Zdepth
      disp(sprintf('Reading frame %d (total %d)', i,data.Zdepth))

      if(isempty(preloadStack))
        tmp = imread(fileName,i);
      else
        tmp = preloadStack(i).data;
      end

      % If there is more than just grayscale info then sum channels together
      if(size(tmp,3) > 1)
        tmp = sum(tmp,3);
      end

      data.img(:,:,i) = tmp;
    end

    % Useful information about the image
    data.max = max(data.img(:));
    data.median = median(data.img(:));
    data.center = ceil(data.Zdepth/2);

    % Allocate a neuron mask
    data.neuronMask = zeros(data.height,data.width);

    % Reset view of the image

    img.showZ = data.center;
    img.intensityLow = 0;
    img.intensityHigh = data.max;
    img.isPlotted = 0;
    img.showPutativeCenters = 1;
    detection.done = 0;

    set(handles.zSlider, 'Max',data.Zdepth,'Min',1, ...
	'SliderStep', [1/data.Zdepth 5/data.Zdepth], ...
	'Value',img.showZ);

    set(handles.zText,'String',num2str(img.showZ));

    % Locate the center of the putative neurons
    findNeuronCenters();

    % Create smoothed data for edge detection.
    smoothDataForEdgeDetection();

    % Display GUI available after loading new image
    showImage();
    showCenterButtons();
    drawnow

    saveStateForUndo('not possible');

    % Show final result...
    showImage();

    if(isempty(handles.menuItemCorr))
      % Allow for correlation detection
      handles.menuItemCorr = uimenu(handles.menuFile, ...
				    'Label', ...
				    'Morphology from correlation (experimental)', ...
				    'Interruptible','off', ...
				    'Callback', @morphologyFromCorrelation);
    end

    % Now we add import button
    if(isempty(handles.importMask))
      % We also add the import feature
      handles.importMask = uimenu(handles.menuFile, ...
				  'Label', 'Import mask', ...
				  'Interruptible', 'off', ...
				  'Callback', @importMask);
				  
    end


    set(handles.detectEdges,'String','Detect edges');

    % Turn button green to indicate that it is safe to pres
    set(handles.detectEdges, 'BackgroundColor', get(gcf,'color'))

  end 

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function morphologyFromCorrelation(source, eventdata)

    % Average 5 frames together
    binStep = 10; %5;

    % Select a tiff-stack to load
    [tiffFile, tiffPath, fileType] = ...
      uigetfile({'*.tif', ...
		 'Select a tiff trace with events'; ...
		 '*.stk', ...
		 'Select a stk file with events'});

    if(isequal(tiffFile,0) | isequal(tiffPath,0))
      % No file selected to load
      return
    end

    fileName = [tiffPath tiffFile]
    disp(sprintf('Loading %s', fileName))

    switch(fileType)
      case 1
        tiffInfo = imfinfo(fileName);
        nFrames = length(tiffInfo);

        if(data.height ~= tiffInfo(1).Height ...
           | data.width ~= tiffInfo(1).Width)
          disp('Incorrect dimension on tiff-trace')
          beep
          return
        end

        preloadedTrace = [];
      case 2
        preloadedTrace = tiffread(fileName);    
	nFrames = length(preloadedTrace);

        if(data.height ~= preloadedTrace(1).height ...
           | data.width ~= preloadedTrace(1).width)
          disp('Incorrect dimension on tiff-trace')
          beep
          return
        end

      otherwise
        disp('What on earth... error!')
        keyboard
    end

    stepIdx = 1:binStep:nFrames;

    traceImg = zeros(data.height,data.width,length(stepIdx));

    for i = 1:(length(stepIdx)-1)

      tmpSum = zeros(data.height,data.width);

      for j = 0:binStep-1
	frameIdx = stepIdx(i)+j;
	disp(sprintf('Reading frame %d (total %d)', ...
		     frameIdx,nFrames))

	if(isempty(preloadedTrace))
          tmp = imread(fileName,frameIdx);
        else
	  tmp = preloadedTrace(frameIdx).data;
        end

        % If there is more than just grayscale info then sum channels together
        if(size(tmp,3) > 1)
          tmp = sum(tmp,3);
        end

        tmpSum = tmpSum + double(tmp);

      end

      traceImg(:,:,i) = tmpSum;

    end

    % Now image is loaded, check correlation with neighbour to the left
    % and with neighbour below.

    [xLeft,yLeft]   = meshgrid(1:data.width-1,1:data.height);
    [xRight,yRight] = meshgrid(2:data.width,1:data.height);
    [xAbove,yAbove] = meshgrid(1:data.width,1:data.height-1);
    [xBelow,yBelow] = meshgrid(1:data.width,2:data.height);    

    rightCorr = zeros(size(yLeft));
    belowCorr = zeros(size(yAbove));
    randCorr = zeros(size(yLeft));

    for i = 1:numel(yLeft)
      if(mod(i,10000) == 0)
        fprintf('Left correlating: %d/%d\n',i,numel(yLeft))
      end

      tmp = corrcoef(traceImg(yLeft(i),xLeft(i),:), ...
		     traceImg(yRight(i),xRight(i),:));
      rightCorr(i) = tmp(2);

    end

    for i = 1:numel(yAbove)
      if(mod(i,10000) == 0)
        fprintf('Below correlating: %d/%d\n',i,numel(yAbove))
      end

      tmp = corrcoef(traceImg(yAbove(i),xAbove(i),:), ...
		     traceImg(yBelow(i),xBelow(i),:));
      belowCorr(i) = tmp(2);

    end

    useStatisticThreshold = 1;

    if(useStatisticThreshold)

      for i = 1:numel(yLeft)

        xRand1 = 1; yRand1 = 1; xRand2 = 1; yRand2 = 1;
 
        % We want to avoid self comparisons
        while(xRand1 == xRand2 & yRand1 == yRand2)

          if(mod(i,10000) == 0)
            fprintf('Random correlating: %d/%d\n',i,numel(yLeft))
          end

          yRand1 = ceil(rand(1)*data.height);
          xRand1 = ceil(rand(1)*data.width);

          yRand2 = ceil(rand(1)*data.height);
          xRand2 = ceil(rand(1)*data.width);

        end

        tmp = corrcoef(traceImg(yRand1,xRand1,:), ...
  	  	       traceImg(yRand2,xRand2,:));
        randCorr(i) = tmp(2);

      end

      meanRandCorr = mean(randCorr(:));
      stdRandCorr  = std(randCorr(:));

      corrCutOff = meanRandCorr + 3*stdRandCorr;
    else
      corrCutOff = 0.5;
    end

    fprintf('Using cut-off : %d\n', corrCutOff)

    rightMask = rightCorr > corrCutOff;
    belowMask = belowCorr > corrCutOff;

    neuronMaskW = zeros(data.height,data.width);
    neuronMaskH = zeros(data.height,data.width);

    neuronMaskW(1:end,1:end-1) = rightMask;
    neuronMaskW(1:end,2:end)   = neuronMaskW(1:end,2:end) + rightMask;
    neuronMaskH(1:end-1,1:end) = belowMask;
    neuronMaskH(2:end,1:end)   = neuronMaskH(2:end,1:end) + belowMask;

    data.neuronMask = double(neuronMaskH & neuronMaskW);

    d = strel('disk',1)
    data.neuronMask = imerode(data.neuronMask,d);
    % data.neuronMask = imclose(data.neuronMask,d);

    updateConnectivityInfo();
    filterMask(6*6);
    updateConnectivityInfo();

    img.showPutativeCenters = 0;
    detection.done = 1;

    saveStateForUndo(' correlation detected neurons');     
    showImage();
    showEdgeButtons();


    % Now we add the save button, since there is something to save
    if(isempty(handles.menuItemSave))

      handles.menuItemSave = uimenu(handles.menuFile, ...
				    'Label','save Mask', ...
				    'Interruptible', 'off', ...
				    'Callback', @saveData);
    end



  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %%% Import previously saved mask

  function importMask(source, eventdata)

    [dataFile dataPath] = ...
      uigetfile({'*-mask.mat','Mask file'; '*.mat','MAT-file'}, ...
		'Select neuron mask file', ...
		'MultiSelect','off');

    if(dataFile == 0)
      % User pressed cancel
      return;
    end

    tmp = load([dataPath dataFile]);

    if(data.height ~= tmp.saveData.height ...
       | data.width ~= tmp.saveData.width)
      errordlg('Unable to import mask. Height and width does not match.', ...
	       'Import error', 'modal')
      return
    end

    data.neuronMask = tmp.saveData.neuronMask;

    detection.done = 1;
    img.showPutativeCenters = 0;

    updateConnectivityInfo();
    saveStateForUndo(' imported mask');     
    showImage();

    disp(sprintf('Mask from %s imported.', dataFile))

    % Now we add the save button, since there is something to save
    if(isempty(handles.menuItemSave))

      handles.menuItemSave = uimenu(handles.menuFile, ...
				    'Label','save Mask', ...
				    'Interruptible', 'off', ...
				    'Callback', @saveData);
    end

    % Clear pia info
    data.piaDist = [];
    data.piaPosition = [];

 end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %%% Save data to file %%%%%%%%%%


  function saveData(source, eventdata)
    disp('Save data called')

    % Exclude all neurons smaller than N pixels
    filterMask(detection.minSize);

    % Just to make sure we have the latest connection info
    updateConnectivityInfo();
    showImage();

    % If we have a pia mask, make sure the distances are up to date
    if(~isempty(data.piaDist))
      centroid = cat(1,data.neuronComponentsProps.Centroid);
      pixelIdxList = data.neuronComponents.PixelIdxList;

      [data.piaDist, data.piaPosition] = ...
          EvA_piaHelper(data.neuronMask, centroid, pixelIdxList, ...
		      data.xRes, data.yRes, data.piaPosition);
    end

    saveFileSuggestion = strrep(data.file,'.tif','-mask.mat');
    saveFileSuggestion = strrep(saveFileSuggestion,'.tiff','-mask.mat');
    saveFileSuggestion = strrep(saveFileSuggestion,'.TIF','-mask.mat');
    saveFileSuggestion = strrep(saveFileSuggestion,'.stk','-mask.mat');

    saveData.file   = data.file;
    saveData.height = data.height;
    saveData.width  = data.width;
    saveData.Zdepth = data.Zdepth;
    saveData.neuronMask = data.neuronMask;
    saveData.pixelList = data.neuronComponents.PixelIdxList;
    saveData.neuronMaskNumbered = zeros(size(data.neuronMask));
    saveData.numNeurons = length(saveData.pixelList);
    saveData.imgDispInfo = img;

    for i=1:length(saveData.pixelList)
      saveData.pixelsPerNeuron(i) = length(saveData.pixelList{i});

      for j=1:length(saveData.pixelList{i})
        saveData.centroid(i,:) = data.neuronComponentsProps(i).Centroid;
        saveData.neuronMaskNumbered(saveData.pixelList{i}(j)) = i;
      end
    end

    saveData.xRes = data.xRes;
    saveData.yRes = data.yRes;
    saveData.zRes = data.zRes;
    saveData.freq = data.freq;

    saveData.piaDist = data.piaDist;

    uisave('saveData',saveFileSuggestion)
    
    saveConfig();
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function setzSlider(source, eventdata)

    img.showZ = round(get(handles.zSlider,'Value'));
    set(handles.zText,'String', sprintf('%.0f',img.showZ));

    showImage();

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function setzText(source, eventdata)

    tmp = str2num(get(handles.zText,'String'));

    if(isempty(tmp) | tmp < 0 | tmp > data.Zdepth)
      % Invalid value inputed, must be integer
      set(handles.zText,'String', sprintf('%.0f',img.showZ));    
    end

    img.showZ = round(tmp);
    set(handles.zSlider,'Value',img.showZ);

    showImage();
  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function setPutativeThresholdSlider(source, eventdata)

    if(~isempty(data.img))
      detection.putativeThreshold = get(handles.centerThresh,'Value');

      findNeuronCenters(); 

      updatePutativeThresholdGUI();

      data.neuronMask = zeros(size(data.neuronMask));
      updateConnectivityInfo(); 
      saveStateForUndo(' detection restart');     
      showImage();

    else
      updatePutativeThresholdGUI();
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function updatePutativeThresholdGUI()

    set(handles.threshText,'String', ...
	sprintf('Threshold for center detection: %.3f', ...
		detection.putativeThreshold));

    set(handles.centerThresh,'Value',detection.putativeThreshold);

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function updateToggleZGUI()
    set(handles.Ztext,'String', ...
	sprintf('Include frames +/-%d of Z-center', detection.Zspacing));
    set(handles.includeZdepth,'Value', detection.useZspacing);
	
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function toggleIncludeZdepth(source, eventdata)

    detection.useZspacing = get(handles.includeZdepth,'Value');
  
    findNeuronCenters(); 

    data.neuronMask = zeros(size(data.neuronMask));
    updateConnectivityInfo(); 
    saveStateForUndo(' detection restart');     
    showImage();

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function updateBGGUI()
    set(handles.useBGremoval,'Value', detection.useBGremoval);
	
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function toggleUseBGremoval(source, eventdata)

    detection.useBGremoval = get(handles.useBGremoval,'Value');
  
    findNeuronCenters(); 

    data.neuronMask = zeros(size(data.neuronMask));
    updateConnectivityInfo(); 
    saveStateForUndo(' detection restart');     
    showImage();

  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function setMinEdgeThresholdSlider(source, eventData)

    detection.minEdgeThresh = get(handles.edgeMinThresh,'Value');

    updateMinEdgeThresholdGUI();

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function updateMinEdgeThresholdGUI()

    if(detection.autoThreshold)
      set(handles.edgeText,'String', ...
	  'Minimize cross-entropy to find threshold');
      set(handles.edgeMinThresh,'visible','off')
    else
      set(handles.edgeText,'String', ...
	  sprintf('Lower threshold for edge detection: %.3f', ...
		  detection.minEdgeThresh));

      set(handles.edgeMinThresh,'Value', detection.minEdgeThresh);
      set(handles.edgeMinThresh,'visible','on')
    end

    if(img.showPutativeCenters)
      set(handles.edgeMinThresh,'visible','off')
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function showImage()

    if(isempty(data.img))
      % Nothing to display, just return
      return
    end

    % Show the histogram over the colour intensity
    set(handles.fig,'CurrentAxes',handles.hist)

    cla
    edges = linspace(0,data.max,1000);
    binN = histc(data.img(:),edges);
    preRange = find(edges < img.intensityLow);
    postRange = find(edges > img.intensityHigh);
    colRange = find(img.intensityLow <= edges ...
		    & edges <= img.intensityHigh);

    if(~isempty(preRange))
      b = bar(edges(preRange), binN(preRange), ...
	      'facecolor', [0.5 0.5 0.5], 'edgecolor', [0.5 0.5 0.5]);
      hold on
    end
    if(~isempty(colRange))
      b = bar(edges(colRange), binN(colRange), ...
	      'facecolor', [0 0 0], 'edgecolor', [0 0 0]);
      hold on
    end
    if(~isempty(postRange))
      b = bar(edges(postRange), binN(postRange), ...
	      'facecolor', [0.5 0.5 0.5], 'edgecolor', [0.5 0.5 0.5]);
      hold on
    end

    %hist(data.img(:),1000,'facecolor',[0 0 0]), hold on

    axis tight, box off
    img.histAxis = axis(); 
    set(gca,'xtick', [], 'ytick', [])

    plot([1 1]*img.intensityLow,img.histAxis(3:4),'b-')
    plot([1 1]*img.intensityHigh,img.histAxis(3:4),'r-')

 
    % Show the detected neurons in the left figure
    set(handles.fig,'CurrentAxes',handles.plotLeft)
    oldAxis = axis();
    
    tmp = zeros(data.height,data.width,3);
    tmp2 = interp1([img.intensityLow img.intensityHigh], ...
		   [0 1], ...
		   data.img(:,:,data.center));
    tmp2(data.img(:,:,data.center) < img.intensityLow) = 0;
    tmp2(data.img(:,:,data.center) > img.intensityHigh) = 1;

    tmp(:,:,1) = 0.5*data.neuronMask + 0.5*tmp2;
    tmp(:,:,2) = 0.5*tmp2;
    tmp(:,:,3) = 0.25*data.neuronMask + 0.5*tmp2;

    if(img.showGrid)
      tmp(100:100:end,:,2) = 0.2;
      tmp(:,100:100:end,2) = 0.2;
    end

    imgHandle = imshow(tmp);

    if(img.showPutativeCenters & ~isempty(data.putativeCenter))
      hold on
      pImg = plot(data.putativeCenter(:,1),data.putativeCenter(:,2),'r*');
      hold off    
    end

    if(detection.done)
      set(imgHandle,'UIContextMenu',handles.modifyNeurons);
    end

    % This restores the old zoom level in case we need to
    if(img.isPlotted)
      axis(oldAxis);
    end

    % Show the raw image in the right figure
    set(handles.fig,'CurrentAxes',handles.plotRight)

    tmp = zeros(data.height,data.width,3);
    tmp2 = interp1([img.intensityLow img.intensityHigh], ...
		   [0 1], ...
		   data.img(:,:,img.showZ));
    tmp2(data.img(:,:,img.showZ) < img.intensityLow) = 0;
    tmp2(data.img(:,:,img.showZ) > img.intensityHigh) = 1;

    tmp(:,:,2) = tmp2;

    if(img.showGrid)
      tmp(100:100:end,:,1) = 0.3;
      tmp(:,100:100:end,1) = 0.3;
    end

    imshow(tmp);

    % Restore the axis for the second figure also, and set flag that 
    % both are plotted
    if(img.isPlotted)
      axis(oldAxis);
    else
      img.isPlotted = 1;
    end

    linkaxes([handles.plotLeft handles.plotRight], 'xy')

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %%% Take care of when a mouse button is pressed 
  %   (this handles histogram, the slice, and the left plot)

  function MouseButtonDownHandler(source,eventdata)
    %disp('Pressed key')

    if(isempty(data.img))
      disp('No image is loaded, ignoring clicks')
      return
    end

    tmpXY = get(handles.hist,'CurrentPoint');

    if(img.isPlotted ...
       & img.histAxis(1) <= tmpXY(1,1) & tmpXY(1,1) <= img.histAxis(2) ...
       & img.histAxis(3) <= tmpXY(1,2) & tmpXY(1,2) <= img.histAxis(4))

      % Clicked inside of histogram, update borders

      switch(get(handles.fig,'SelectionType'))
        case 'normal'
	  % Click to change upper range
	  if(tmpXY(1) < img.intensityLow)
	    % User clicked below LOW limit, we cant move higher range
	    % so lets move lower
	    img.intensityLow = round(tmpXY(1)); 
          else
	    % Update high
	    img.intensityHigh = round(tmpXY(1));
          end
        case 'alt'
	  % Right click to change lower range
          if(tmpXY(1) > img.intensityHigh)
	    % Hmm, user clicked above HIGH limit, move high instead
            img.intensityHigh = round(tmpXY(1));
	  else
	    % Update low
            img.intensityLow = round(tmpXY(1));
          end
        end

      showImage()
    end

    tmpXY = get(handles.plotLeft,'CurrentPoint');

    % Are we inside the left plot?
    x = round(tmpXY(1,1)); 
    y = round(tmpXY(1,2));

    set(handles.fig,'CurrentAxes',handles.plotLeft)
    axisLeft = axis();

    if(img.isPlotted ...
       & axisLeft(1) <= x & x <= axisLeft(2) ...
       & axisLeft(3) <= y & y <= axisLeft(4))
      % Button pressed inside the left plot

      switch(get(handles.fig,'SelectionType'))
        case 'normal'
          % Have we detected neurons, otherwise do not allow editing
          % of the neuron mask

          if(detection.done)

            % Mouse was pressed in our figure, check if it was 
            % a masked or unmasked pixel underneath.
            % Update state of draw-mode, and pixel underneath accordingly

            % !!!! Checking....
            if(y > data.height | x > data.width)
              disp('Talk to Johannes, this should not happen!')
              beep
              keyboard
            end

            if(data.neuronMask(y,x))
              % Pixel underneath, start removing pixels from mask
              %disp('Removing')
              editInfo.mouseEditMode = 0;
            else
              % No pixel underneath, add pixels until button released
              %disp('Adding')
              editInfo.mouseEditMode = 1;
            end

            data.neuronMask(y,x) = editInfo.mouseEditMode;

            % disp('Detected mouse press')
            % showImage();
            paintPixel(x,y); % Just update the pixel, faster

            % Start tracking mouse movements
  	    set(handles.fig, 'WindowButtonMotionFcn', @MouseMovedHandler, ...
		             'WindowButtonUpFcn', @MouseButtonUpHandler)
          end
        case 'alt'
          % Right click detected

          % Make sure we are in center editing mode
  	  if(img.showPutativeCenters)

            % Find where the user clicked
            tmpXY = get(handles.plotLeft,'CurrentPoint');
            xCenter = tmpXY(1,1);
            yCenter = tmpXY(1,2);

            pDist = (data.putativeCenter(:,1) - xCenter).^2 ...
                     + (data.putativeCenter(:,2) - yCenter).^2;

            pIdx = find(pDist == min(pDist));
   
            % Overwrite the old red star with a black one
            set(handles.fig,'CurrentAxes',handles.plotLeft)
            hold on
            plot(data.putativeCenter(pIdx,1),data.putativeCenter(pIdx,2),'k*');
            hold off

            % Remove the neuron in question
            data.putativeCenter(pIdx,:) = [];

            % Dont redraw screen, slow and sluggish
            % showImage();
          end
        otherwise
          % Right clicks etc are not handled by this function
      end
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function MouseButtonUpHandler(source,eventdata)
    if(source == handles.fig & img.isPlotted)
      % Mouse was released, stop tracking mouse

      % disp('Detected mouse released')
      stopTrackingMouse();
      showImage();
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function MouseMovedHandler(source, eventdata)

    if(source == handles.fig)
      tmpXY = get(handles.plotLeft,'CurrentPoint');
      x = round(tmpXY(1,1)); 
      y = round(tmpXY(1,2));

      axisLeft = axis();

      if(axisLeft(1) <= x & x <= axisLeft(2) ...
	 & axisLeft(3) <= y & y <= axisLeft(4))
        % Button pressed inside the plot

        if(data.neuronMask(y,x) ~= editInfo.mouseEditMode)
          data.neuronMask(y,x) = editInfo.mouseEditMode;
          paintPixel(x,y); % Just update the pixel, faster
        end
      else
        % We moved out of the plot, stop tracking mouse
        stopTrackingMouse();
        showImage();
        % disp('Moved out of plot, stop tracking mouse')
      end

      % disp('Detected mouse moved')

    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function stopTrackingMouse()
      % Stop following mouse movement
      set(handles.fig, 'WindowButtonMotionFcn', '');
      set(handles.fig,'WindowButtonUpFcn', '')

      % Since we modified the neuron mask we need to recalculate
      % the pixel lists etc.
      updateConnectivityInfo();

      %%% Add undo information
      if(editInfo.mouseEditMode)
        saveStateForUndo('add pixels');
      else
        saveStateForUndo('remove pixels');
      end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function paintPixel(x,y)
    % Update neuron mask
    data.neuronMask(y,x) = editInfo.mouseEditMode();
    pixelCol = [0 0 0];

    if(editInfo.mouseEditMode())
      % Draw it pink
      pixelCol = [0.5 0.25 0.5];
    end

    % Draw a rectangle depending on which editing mode we are in
    % Show the detected neurons in the left figure

    set(handles.fig,'CurrentAxes',handles.plotLeft)
    hold on
    patch([x-0.5 x+0.5 x+0.5 x-0.5], ...
	  [y-0.5 y-0.5 y+0.5 y+0.5], ...
	  pixelCol, 'linestyle', 'none');
    hold off

  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %%% These handle right click on the gray image to add/delete neurons 
 
  % Finding edges of neuron using 3D information

  function addNeuron3DCallback(source, eventData)


    % Find where the user clicked
    tmpXY = get(handles.plotLeft,'CurrentPoint');
    xCenter = round(tmpXY(1,1));
    yCenter = round(tmpXY(1,2));

    % Guess the Z-coordinate
    zData = data.img(yCenter,xCenter,:);
    % [foo, zCenter] = max(zData);
    zCenter = data.center;

    centerP = [xCenter yCenter zCenter];
    
    if(detection.autoThreshold)
      [centerP, outX, outY, outZ, cellVolume] = ...
        findNeuronEdgesAuto(centerP,1);
    else
      [centerP, outX, outY, outZ, cellVolume] = ...
        findNeuronEdges(centerP);
    end

    % We project all the spheres points on a plane, 
    % then we want to find those that are exterior points. 
    if(~isempty(centerP))
      projectEdgesToPlane(outX,outY,outZ);

      updateConnectivityInfo();
      saveStateForUndo('add neuron (3D)');
      showImage();
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %%% Removal of neurons

  function deleteNeuronCallback(source, eventData)

    tmpXY = get(handles.plotLeft,'CurrentPoint');
    x = round(tmpXY(1,1));
    y = round(tmpXY(1,2));

    removeIdx = [];

    % Which neuron is the pixel a member of (if any)
    for i=1:length(data.neuronComponents.PixelIdxList)
      idx = sub2ind([data.height data.width],y,x);

      if(ismember(idx,data.neuronComponents.PixelIdxList{i}))
        removeIdx(end+1) = i;
      end
    end

    % Remove the neuron
    for i=1:length(removeIdx)
      %disp(sprintf('Removing neuron %d', removeIdx(i)))
      data.neuronMask(data.neuronComponents.PixelIdxList{removeIdx(i)}) = 0;
    end

    updateConnectivityInfo();
    saveStateForUndo('delete neuron');
    showImage();
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function addNeuronROI(source, event)

    set(handles.fig,'CurrentAxes',handles.plotLeft)

    oldDownHandler = get(handles.fig,'WindowButtonDownFcn');
    set(handles.fig,'WindowButtonDownFcn', []);

    try
      bw = roipoly();

      if(~isempty(bw))
        data.neuronMask = double(data.neuronMask + bw > 0);

        updateConnectivityInfo();
        saveStateForUndo('add neuron (ROI)');
        showImage();

      end
    catch exception
      getReport(exception);
      disp('Trying to recover.')
    end

    set(handles.fig,'WindowButtonDownFcn', oldDownHandler);

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %%% We now split up the neuron detection into two steps,
  % 
  % 1. First the user gets to inspect the putative neurons center
  %
  % 2. Then once those are confirmed, the edge detection starts
  %
  % 3. The user can trim the edges.
  %
  %

  function [localMaxXY, localMaxValue] = findLocalMax(Zplane)

    %disk = fspecial('disk',5);
    disk = fspecial('gaussian',100,detection.smoothing);

    if(detection.useBGremoval)
      diskBG = fspecial('gaussian',100,30);
      smoothImg = imfilter(data.img(:,:,Zplane),disk) ...
	          - imfilter(data.img(:,:,Zplane),diskBG);
    else
      smoothImg = imfilter(data.img(:,:,Zplane),disk);
    end

    tmp = sort(smoothImg(:));
    tmpThresh = tmp(ceil(numel(tmp)*detection.putativeThreshold));

    % Remove all local max below a certain intensity threshold
    smoothImg(smoothImg < tmpThresh) = tmpThresh;
  
    disp('Locating regional max')
    % First find the voxels which are larger than all surrounding voxels
    localMaxMask = imregionalmax(smoothImg);

    idx = find(localMaxMask);
    localMaxValue = smoothImg(idx);
    [y,x] = ind2sub(size(localMaxMask),idx);

    localMaxXY = [x,y];

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function findNeuronCenters()
    % This function assumes data.img is loaded
    localMaxZdepth = data.center;

    if(detection.useZspacing)
      % localMaxZdepth = data.center + [-1 0 1]*detection.Zspacing;
      localMaxZdepth = data.center + [-detection.Zspacing:detection.Zspacing];
    end

    localMaximumXY = [];
    localMaximumValue = [];

    for lIdx = 1:length(localMaxZdepth)
      [tmpXY, tmpVal] = findLocalMax(localMaxZdepth(lIdx));
      localMaximumXY = [localMaximumXY; tmpXY];
      localMaximumValue = [localMaximumValue; tmpVal];
    end

    % Now, we want to remove the local maximas that have a larger
    % maxima within a minimum distance
    disp('Filtering regional max')

    % Sort the local maximum in order of size
    [tmp, lIdx] = sort(localMaximumValue,'descend');
    localMaximumXY = localMaximumXY(lIdx,:);
    localMaximumValue = localMaximumValue(lIdx);

    keepLocalMax = ones(size(localMaximumValue));

    for k=1:size(localMaximumXY,1)
      xMid = localMaximumXY(k,1);
      yMid = localMaximumXY(k,2);

      % A local max can only remove another if it has not 
      % already been removed.
      if(keepLocalMax(k))
	% We only check with local maximums after our point
	% since they are sorted in descending order
        lDist = sqrt((localMaximumXY((k+1):end,1)-xMid).^2 ...
		     + (localMaximumXY((k+1):end,2)-yMid).^2);

        % Find points after current one which are within range
        % and exclude them as local maximas, since they are smaller
        rIdx = k + find(lDist <= detection.minNeuronDist);
	       
        % Remove the smaller local maximas within range
	keepLocalMax(rIdx) = 0;
      end
    end



    xCenter = localMaximumXY(find(keepLocalMax),1);
    yCenter = localMaximumXY(find(keepLocalMax),2);
 
    % Allocate room for the z-coordinate
    zCenter = NaN*xCenter;

    % We were just looking for local maximas in plane this time
    % so need to guess the z-coordinate.
    for pCtr=1:numel(xCenter)
      % Guess the Z-coordinate

      zData = data.img(yCenter(pCtr),xCenter(pCtr),:);

      % This is a weighted sum of the intensities, to find the
      % "centre of intensity mass" so to speak...

      if(1)
        zCenter(pCtr) = round(sum(squeeze(zData) ...
      				.*transpose(1:data.Zdepth))/sum(zData));

      else
        % lets just seed with the center plane instead
        zCenter(pCtr) = data.center;
      end
    end

    data.putativeCenter = [xCenter yCenter zCenter];

   img.showPutativeCenters = 1;

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function detectNeurons()

    data.neuronMask = zeros(data.height,data.width);
    neuronCtr = 0;

    waitBar = waitbar(0, 'Detecting neurons... (0 found)');

    fidVol = 0;
    outputToFile = true;
    
    for iCent=1:size(data.putativeCenter,1)

      if(detection.autoThreshold)
        [centerPoint, outX, outY, outZ, cellVolume] = ...
            findNeuronEdgesAuto(data.putativeCenter(iCent,:),1);
      else
        [centerPoint, outX, outY, outZ, cellVolume] = ...
            findNeuronEdges(data.putativeCenter(iCent,:));
      end

      if(~isempty(centerPoint))
        % We found a neuron

        % We project all the spheres points on a plane, 
        % then we want to find those that are exterior points.
        projectEdgesToPlane(outX,outY,outZ);

        neuronCtr = neuronCtr+1;

        if(mod(iCent,10) == 0)
          waitbar(iCent/size(data.putativeCenter,1), ...
                  waitBar, ...
                  sprintf('Detecting neurons... (%d found)', ...
                          neuronCtr))
        end
        
        if(outputToFile)
          if(~fidVol)
            fNameVol = sprintf('cell-vols-%s.csv', data.file);
            fidVol = fopen(fNameVol,'w');
            fprintf('Writing cell volumes to %s\n', fNameVol)
          end
          
          fprintf(fidVol, '%f,%f,%f,%f\n', centerPoint(1), centerPoint(2), ...
                  centerPoint(3), cellVolume);
          
        end
        
      end

    end

    if(fidVol)
      fclose(fidVol);
      fidVol = 0;
    end
      
    
    waitbar(1, waitBar, ...
	    sprintf('Detecting neurons... (%d found)', ...
		    neuronCtr))


    % Hide the centers
    img.showPutativeCenters = 0;

    delete(waitBar);
    detection.done = 1;
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function smoothDataForEdgeDetection()
    if(size(data.img,3) <= 1)
      disp('More than one Z-plane required for smoothing')
      return
    end

    xLin = (0:data.width-1)*data.xRes;
    yLin = (0:data.height-1)*data.yRes;
    zLin = (0:data.Zdepth-1)*data.zRes;

    [data.X,data.Y,data.Z] = meshgrid(xLin,yLin,zLin);

    % Smooth the image prior to edge detection
    data.smoothImg = smooth3(data.img,'box',3);

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  preCalcOffsets.x = [];
  preCalcOffsets.y = [];
  preCalcOffsets.z = [];

  function unsortedPoints = extractRegion(x,y,z)

    if(isempty(preCalcOffsets.x))

      scaleR = 1; %0.5; % 1 = Use entire sphere

      xMax = round(scaleR*detection.maxR/data.xRes);
      yMax = round(scaleR*detection.maxR/data.yRes);
      zMax = round(scaleR*detection.maxR/data.zRes);


      [yReg,xReg,zReg] = meshgrid(-yMax:yMax, -xMax:xMax, -zMax:zMax);
      distReg = sqrt(xReg.^2+yReg.^2+zReg.^2);

      okOfs = find(distReg < detection.maxR);

      preCalcOffsets.x = xReg(okOfs);
      preCalcOffsets.y = yReg(okOfs);
      preCalcOffsets.z = zReg(okOfs);

    end

    xReg = x + preCalcOffsets.x;
    yReg = y + preCalcOffsets.y;
    zReg = z + preCalcOffsets.z;

    okIdx = find(1 <= xReg & xReg <= data.width ...
		 & 1 <= yReg & yReg <= data.height ...
		 & 1 <= zReg & zReg <= data.Zdepth);

    imgIdx = sub2ind(size(data.img),yReg(okIdx),xReg(okIdx),zReg(okIdx));

    unsortedPoints = data.img(imgIdx);

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function threshold = minimizeCrossEntropy(grayImage)


    % Implementing Brink and Pendock 1996
    % "Minimum Cross-Entropy Threshold Selection", eq 11.
    % doi:10.1016/0031-3203(95)00066-6   

    offset = 1; % To avoid division by 0

    minG = min(grayImage(:)+offset);
    maxG = max(grayImage(:)+offset);
  
    edges = transpose(minG:maxG);
    freqG = histc(grayImage(:),edges);

    threshold = NaN;
    minH = inf;

    % Golden section search
    phi = (1 + sqrt(5))/2;
    resphi = 2 - phi;

    G1 = minG;
    G2 = minG + (maxG-minG)*resphi;
    G3 = maxG;

    H1 = crossEntropy(G1,edges,freqG);
    H2 = crossEntropy(G2,edges,freqG);
    H3 = crossEntropy(G3,edges,freqG);

    Hctr = 3;

    while(abs(G1 - G3) > 0.5)
      G4 = G2  + resphi*(G3 - G2);

      H4 = crossEntropy(G4,edges,freqG);
      Hctr = Hctr + 1;

      if(H4 < H2)
        G1 = G2; H1 = H2;
        G2 = G4; H2 = H4;  
        % G3 unchanged
      else
	G3 = G1; H3 = H1;
        % G2 unchanged
	G1 = G4; H1 = H4;       
      end

    end

    threshold = round((G1 + G3)/2);

    fprintf('Threshold %.0f minimizes cross-entropy.\n',threshold)
    fprintf('Speedup is %.0f times\n', (maxG-minG+1)/Hctr);

  end


  function H = crossEntropy(thresh, edges, freqG)

      % The two distributions are separated by a threshold
      % idx = find(edges == thresh);
      tmp = abs(edges - thresh);
      [value,idx] = min(tmp);

      % How to deal with val0(1) = 0, that will give H=NaN
      val0 = edges(1:idx-1);
      freq0 = freqG(1:idx-1);

      val1 = edges(idx:end);
      freq1 = freqG(idx:end);
      
      % Calculate mean values for the two distributions
      mu0 = sum(val0.*freq0)/sum(freq0);
      mu1 = sum(val1.*freq1)/sum(freq1);
      
      % Calculate cross-entropy measure
      H = nansum(freq0.*(mu0.*log(mu0./val0) + val0.*log(val0./mu0))) ...
	+ nansum(freq1.*(mu1.*log(mu1./val1) + val1.*log(val1./mu1)));

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function threshold = minimizeCrossEntropyOldSlow(grayImage)


    % Implementing Brink and Pendock 1996
    % "Minimum Cross-Entropy Threshold Selection", eq 11.
    % doi:10.1016/0031-3203(95)00066-6   

    offset = 1; % To avoid division by 0

    minG = min(grayImage(:)+offset);
    maxG = max(grayImage(:)+offset);
  
    edges = transpose(minG:maxG);
    freqG = histc(grayImage(:),edges);

    threshold = NaN;
    minH = inf;

    allH = [];

    % !!! Instead of doing the calculation for every threshold,
    % use fminsearch or some other method to find minima.
    
    for thresh = minG:maxG
  
      % The two distributions are separated by a threshold
      % idx = find(edges == thresh);
      tmp = abs(edges - thresh);
      idx = find(tmp == min(tmp),1);

      % How to deal with val0(1) = 0, that will give H=NaN
      val0 = edges(1:idx-1);
      freq0 = freqG(1:idx-1);

      val1 = edges(idx:end);
      freq1 = freqG(idx:end);
      
      % Calculate mean values for the two distributions
      mu0 = sum(val0.*freq0)/sum(freq0);
      mu1 = sum(val1.*freq1)/sum(freq1);
      
      % Calculate cross-entropy measure
      H = nansum(freq0.*(mu0.*log(mu0./val0) + val0.*log(val0./mu0))) ...
	+ nansum(freq1.*(mu1.*log(mu1./val1) + val1.*log(val1./mu1)));
  
      if(H == 0 | isnan(H))
        keyboard
      end
  
      allH = [allH,H];
  
      if(H < minH)
        minH = H;
        threshold = thresh - offset;
      end
  
    end

    fprintf('Threshold %d minimizes cross-entropy.\n',threshold)

    if(0)
      f = gcf;
      figure, plot(minG:maxG,allH)
      figure(f)
    end
  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function reduceImage(imageRadie)

    % This function removes all but +/- imageRadie frames from center

    if(size(data.img,3) <= 2*imageRadie + 1)
      disp('Nothing to remove.') 
      % Nothing to do
      return
    end

    data.img = data.img(:,:,data.center-imageRadie:data.center+imageRadie);
    data.Zdepth = size(data.img,3);
    data.center = imageRadie + 1;
    data.max = max(data.img(:));
    data.median = median(data.img(:));

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  debugEdges = false;

  function [centerPoint, outXs, outYs, outZs, cellVol] = ...
    findNeuronEdgesAuto(putativeCenter,thresholdScaling)

    % disp('Using threshold using minimization of cross-entropy')

    if(putativeCenter(3) > data.Zdepth)
      disp('This should not be possible')
      keyboard
    end

    % You must call smoothDataForEdgeDetection first

    debugFlag = debugEdges; % 0

    % Center in the micrometer coordinate system
    % We do the transformation, because we want 
    % the sphere to be spherical
    xCent = (putativeCenter(1)-1)*data.xRes;
    yCent = (putativeCenter(2)-1)*data.yRes;
    zCent = (putativeCenter(3)-1)*data.zRes;

    % We iterate this twice, first using the putative centre
    % then repeating it using a better estimate of the centre

    for detectionLoop = 1:2 % 1 % 1:3 %2

      % Place sphere around the neuron center
      [outX,outY,outZ] = sphere(detection.nVert);
      outX = detection.maxR*outX + xCent;
      outY = detection.maxR*outY + yCent;
      outZ = detection.maxR*outZ + zCent;
 
      % We place a grid, centered on neuron,  and going out
      % radially to the vertexes on the surrounding sphere. 
      gridX = NaN*ones(detection.nGrid,numel(outX));
      gridY = NaN*ones(detection.nGrid,numel(outY));
      gridZ = NaN*ones(detection.nGrid,numel(outZ));

      % Calculate the intensity values at all grid points
      % (ie all possible locations for the spheres vertexes)
      for iGrid=1:numel(outX)
        gridX(:,iGrid) = linspace(xCent,outX(iGrid),detection.nGrid);
        gridY(:,iGrid) = linspace(yCent,outY(iGrid),detection.nGrid);
        gridZ(:,iGrid) = linspace(zCent,outZ(iGrid),detection.nGrid);
      end

      gridVal = interp3(data.X,data.Y,data.Z,data.smoothImg, ...
			gridX,gridY,gridZ);

      % Minimize cross-entropy in sphere to find best threshold
      threshVal = minimizeCrossEntropy(gridVal)*thresholdScaling;

      scaleR = zeros(size(gridVal,2),1);

      borderIdxDebug = NaN*zeros(1,size(gridVal,2));

      for iGrid=1:size(gridVal,2)
 
        % We are looking for points where the intensity crosses
        % from above.
        borderIdx = find(gridVal(2:end,iGrid) < threshVal ...
 			 & gridVal(2:end,iGrid) ...
			 < gridVal(1:end-1,iGrid),1);


        if(~isempty(borderIdx))
          scaleR(iGrid,1) =  borderIdx / detection.nGrid;
          borderIdxDebug(iGrid) = borderIdx;
        else
          scaleR(iGrid,1) = 0;         
        end
      end

      outXs = reshape((outX(:)-xCent).*scaleR+xCent,size(outX));
      outYs = reshape((outY(:)-yCent).*scaleR+yCent,size(outY));
      outZs = reshape((outZ(:)-zCent).*scaleR+zCent,size(outZ));

      xCent = nanmean(outXs(:));
      yCent = nanmean(outYs(:));
      zCent = nanmean(outZs(:));

      if(debugFlag)
        figure
        plot(gridVal)
        hold on
        for i = 1:length(borderIdxDebug)
          if(~isnan(borderIdxDebug(i)))
            plot(borderIdxDebug(i),gridVal(borderIdxDebug(i),i),'r*')
            xlabel('Distance from putative centre','fontsize',20)
            ylabel('Intensity','fontsize',20)
            set(gca,'fontsize',20)
            box off
          end
        end
        title(sprintf('Iter: %d, (%d,%d,%d)', ...
                      detectionLoop, xCent, yCent, zCent))
        figure(handles.fig)
      end

    end


    if(nnz(scaleR) > 2)
      % There are at least some non-zero

      % Check if volume constraint is fullfilled
      try
        [foo, cellVol] = ...
          convhulln(unique([outXs(:) outYs(:) outZs(:)],'rows'));
      catch e
        getReport(e)
        disp('If you see this, please let me know right away!')
        disp('If I am not around, email me on hjorth@kth.se')
 	    disp('The code is now in debug mode, type return to resume')
        beep
        save crashinfo
        % keyboard

        % Skip this neuron
        % return
        cellVol = 0;
      end
    else
      % All scale factors are zero, convhulln cant handle this
      % but volume is zero.
      disp('Zero volume, skipping')
      cellVol = 0;
    end

    fprintf('Cell volume = %.1f, neuronPlaneArea = %.1f\n', ...
	    cellVol, neuronPlaneArea(outXs, outYs, outZs))

    if(detection.minVolume <= cellVol ...
       & cellVol <= detection.maxVolume ...
       & neuronPlaneArea(outXs, outYs, outZs) >= detection.minPlaneArea)

      % Found a neuron!

      % Next move back from the micrometer axis to the pixel based axis
      outXs = outXs/data.xRes + 1;
      outYs = outYs/data.yRes + 1;
      outZs = outZs/data.zRes + 1;

      if(debugFlag)
        figure
        colormap copper
        pNeuron = surf(outXs,outYs,outZs);
        shading faceted
        hold on
        a = axis();
        [X,Y,Z] = meshgrid(a(1:2),a(3:4),data.center);
        pSurf = surf(X,Y,Z,0.3*ones(size(Z)));

        alpha(pNeuron,1)
        alpha(pSurf,0.5)
        axis off
        axis equal
        figure(handles.fig);
      end

      % Calculate a new center for the neuron
      newXcent = mean(outXs(:));
      newYcent = mean(outYs(:));
      newZcent = mean(outZs(:));

      disp(sprintf('Found neuron at %.1f %.1f %.1f', ...
		   newXcent, newYcent, newZcent))

      % These are given in pixel coordinates
      centerPoint = [newXcent newYcent newZcent];
      %edgePoints = [outXs(:) outYs(:) outZs(:)];
    else
      % No valid neuron found
      centerPoint = [];
      outXs = [];
      outYs = [];
      outZs = [];
      %edgePoints = [];

      if(thresholdScaling > 0.5)
        disp('Retrying with lower threshold.')
        [centerPoint, outXs, outYs, outZs,cellVol] = ...
            findNeuronEdgesAuto(putativeCenter,thresholdScaling*0.75);
      end
    end

    if(0 & debugEdges)
      disp('In detect edges')
      keyboard
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function [centerPoint, outXs, outYs, outZs, cellVol] = findNeuronEdges(putativeCenter)

    if(putativeCenter(3) > data.Zdepth)
      disp('This should not be possible')
      keyboard
    end

    % You must call smoothDataForEdgeDetection first
    debugFlag = debugEdges;

    % Center in the micrometer coordinate system
    % We do the transformation, because we want 
    % the sphere to be spherical
    xCent = (putativeCenter(1)-1)*data.xRes;
    yCent = (putativeCenter(2)-1)*data.yRes;
    zCent = (putativeCenter(3)-1)*data.zRes;

    % Place sphere around the neuron center
    [outX,outY,outZ] = sphere(detection.nVert);
    outX = detection.maxR*outX + xCent;
    outY = detection.maxR*outY + yCent;
    outZ = detection.maxR*outZ + zCent;
 
    % We place a grid, centered on neuron,  and going out
    % radially to the vertexes on the surrounding sphere. 
    gridX   = NaN*ones(detection.nGrid,numel(outX));
    gridY   = NaN*ones(detection.nGrid,numel(outY));
    gridZ   = NaN*ones(detection.nGrid,numel(outZ));


    foundNeuron = 0;
    threshIdx = 1;

    % Calculate the intensity values at all grid points
    % (ie all possible locations for the spheres vertexes)
    for iGrid=1:numel(outX)
      gridX(:,iGrid) = linspace(xCent,outX(iGrid),detection.nGrid);
      gridY(:,iGrid) = linspace(yCent,outY(iGrid),detection.nGrid);
      gridZ(:,iGrid) = linspace(zCent,outZ(iGrid),detection.nGrid);
    end

    gridVal = interp3(data.X,data.Y,data.Z,data.smoothImg, ...
		      gridX,gridY,gridZ);

    % To remove some noise we a shifted median, the baseline
    % is set by sorting all intensity values in the sphere
    % then finding the value at position 1/8th through.
    tmp = sort(gridVal(:));
    tmp = tmp(~isnan(tmp));

    % minVal = tmp(ceil(numel(tmp)/20));
    minVal = 0;

    if(isnan(detection.maxEdgeThresh))
      if(0)
        % Equally sampling all pixels in the region
        voxelRegion = extractRegion(putativeCenter(1), ...
				    putativeCenter(2), ...
				    putativeCenter(3));

        maxVal = minimizeCrossEntropy(voxelRegion);

      else
      % semi-old version used the sphere grid with denser points in center
        maxVal = minimizeCrossEntropy(gridVal);
      end
    else
      maxVal = tmp(ceil(numel(tmp)*detection.maxEdgeThresh));
    end

    threshRange = linspace(detection.minEdgeThresh,1.5, ...
                           detection.nEdgeSteps);

    % Decrease threshold to see if we can find a neuron
    while(~foundNeuron & threshIdx < length(threshRange))

      % Contract the sphere until it fits the neuron

      relThresh = threshRange(threshIdx);
      threshVal = relThresh*maxVal + (1-relThresh)*minVal;

      if(debugFlag)
        figure
        plot(gridVal)
        hold on
				plot([0 detection.nGrid], threshVal*[1 1],'r--');
				xlabel('Distance to putative centre','fontsize',20)
				ylabel('Intensity','fontsize',20)
				box off
				set(gca,'fontsize',20)
        figure(handles.fig)
      end

      % Calculate how much to shrink the radie of each sphere vertex
      % to fit the neuron. Ie, when does the radial grid line
      % fall below the threshold.
    
      scaleR = zeros(size(gridVal,2),1);

      for iGrid=1:size(gridVal,2)
        %borderPoint = find(gridVal(:,iGrid) < threshVal,1);

        % We are looking for points where the intensity crosses
        % from above.
        borderPoint = find(gridVal(2:end,iGrid) < threshVal ...
			   & gridVal(2:end,iGrid) ...
			   < gridVal(1:end-1,iGrid),1)+1;


        if(~isempty(borderPoint))
          scaleR(iGrid,1) =  borderPoint / detection.nGrid;
        else
          scaleR(iGrid,1) = 0;         
        end
      end

      outXs = reshape((outX(:)-xCent).*scaleR+xCent,size(outX));
      outYs = reshape((outY(:)-yCent).*scaleR+yCent,size(outY));
      outZs = reshape((outZ(:)-zCent).*scaleR+zCent,size(outZ));

      if(nnz(scaleR) > 5)
        % There are at least some non-zero

        % Check if volume constraint is fullfilled
        try
          [foo, cellVol] = ...
              convhulln(unique([outXs(:) outYs(:) outZs(:)],'rows'));

        catch e
          getReport(e)
          disp('If you see this, please let me know right away!')
  	      disp('If I am not around, email me on hjorth@kth.se')
 	      disp('The code is now in debug mode, type return to resume')
          save crashinfo
          % keyboard

          % Skip this neuron
          cellVol = 0;
        end
      else
        % All scale factors are zero, convhulln cant handle this
        % but volume is zero.
        disp('Zero volume, skipping')
        cellVol = 0;
      end

      % Intersection with plane...
      cellArea = neuronPlaneArea(outXs, outYs, outZs);

      if(debugFlag)
        disp(sprintf('Thresh: %d, Cell volume %d, Cell area %d', ...
		     threshVal, cellVol, cellArea))
      end

      if(detection.minVolume <= cellVol ...
         & cellVol <= detection.maxVolume ...
         & cellArea >= detection.minPlaneArea)
        foundNeuron = 1;
      end

      threshIdx = threshIdx + 1;
    end

    if(foundNeuron)
      % Next move back from the micrometer axis to the pixel based axis
      outXs = outXs/data.xRes + 1;
      outYs = outYs/data.yRes + 1;
      outZs = outZs/data.zRes + 1;

      if(debugFlag)
        figure
        colormap copper
        pNeuron = surf(outXs,outYs,outZs);
        shading faceted
        hold on
        a = axis();
        [X,Y,Z] = meshgrid(a(1:2),a(3:4),data.center);
        pSurf = surf(X,Y,Z,0.3*ones(size(Z)));

        alpha(pNeuron,1)
				alpha(pSurf,0.5)
        axis off
        axis equal
        figure(handles.fig);
      end

      % Calculate a new center for the neuron
      newXcent = mean(outXs(:));
      newYcent = mean(outYs(:));
      newZcent = mean(outZs(:));

      disp(sprintf('Found neuron at %.1f %.1f %.1f', ...
		   newXcent, newYcent, newZcent))

      % These are given in pixel coordinates
      centerPoint = [newXcent newYcent newZcent];
      %edgePoints = [outXs(:) outYs(:) outZs(:)];
    else
      centerPoint = [];
      outXs = [];
      outYs = [];
      outZs = [];
      %edgePoints = [];
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function intersectArea = neuronPlaneArea(outX, outY, outZ)
    % This function uses micrometers and NOT pixels as units.

    try
    % interp1 does not handle when values are identical
    tmp = rand(size(outZ,1),1)*1e-7;
    Zcenter = (data.center-1)*data.zRes;

    for theta=1:size(outZ,2)
      % Find x and y coordinates for intersection with center plane
      xEdge(theta,1) = interp1(outZ(:,theta)+tmp,outX(:,theta),Zcenter);
      yEdge(theta,1) = interp1(outZ(:,theta)+tmp,outY(:,theta),Zcenter);
    end
    catch
      save crashinfo
      disp('neuronPlaneArea: Talk to Johannes')
      beep
      keyboard
    end

    uRows = unique([xEdge yEdge],'rows');
    xEdge = uRows(:,1);
    yEdge = uRows(:,2);

    okIdx = find(~isnan(xEdge) & ~isnan(yEdge));
    xEdge = xEdge(okIdx);
    yEdge = yEdge(okIdx);

    intersectArea = 0;

    if(numel(xEdge) > 2)
      try
        [cIdx, intersectArea] = convhull(xEdge,yEdge);
      catch
        save crashinfo
        beep
        disp(sprintf('Crash, talk to Johannes! Sent %d points to convhull',...
		     numel(xEdge)));
      end
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function projectEdgesToPlane(outX, outY, outZ)

    if(isempty(outX))
      return
    end

    xEdge = NaN*ones(size(outZ,2),1);
    yEdge = NaN*ones(size(outZ,2),1);

    try
    % interp1 does not handle when values are identical
    tmp = rand(size(outZ,1),1)*1e-7;

    for theta=1:size(outZ,2)
      xEdge(theta,1) = interp1(outZ(:,theta)+tmp,outX(:,theta),data.center);
      yEdge(theta,1) = interp1(outZ(:,theta)+tmp,outY(:,theta),data.center);
    end
    catch
      save crashinfo
      beep
      disp('projectEdgesToPlane: Talk to Johannes')
      keyboard
    end

    okIdx = find(~isnan(xEdge) & ~isnan(yEdge));
    xEdge = xEdge(okIdx);
    yEdge = yEdge(okIdx);

    try
      if(numel(xEdge) > 2)
        cIdx = convhull(xEdge,yEdge);
        xEdge = xEdge(cIdx);
        yEdge = yEdge(cIdx);


        if(numel(cIdx) > 2)

          if(1)
            % Testing new version
            data.neuronMask = ...
  	      addROItoMask(data.neuronMask, ...
			   roipoly(data.neuronMask, xEdge,yEdge) > 0);
          else
            % Old version
            data.neuronMask = ...
 	    double(data.neuronMask ...
		   + roipoly(data.neuronMask, xEdge,yEdge) > 0);
          end
        end
      end
    catch
      disp('projectEdgesToPlane: Talk to J')
      save crashinfo
      beep
      keyboard
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function mask = largestComponent(mask)
    CC = bwconncomp(mask);

    maxCC = 0;
    maxCCidx = 0;
    for i = 1:length(CC.PixelIdxList)
      if(length(CC.PixelIdxList{i}) > maxCC)
	maxCCidx = i;
        maxCC = length(CC.PixelIdxList{i});
      end
    end

    % Keep only largest connected component when doing soma detection
    mask(:) = 0;
    if(maxCCidx)
      mask(CC.PixelIdxList{maxCCidx}) = 1;
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function newMask = addROItoMask(oldMask,ROImask)

    % Pad the old mask with one pixel
    disk = strel('disk',2);
    paddedMask = imdilate(oldMask,disk);


    ROIidx = find(ROImask);

    if(nnz(paddedMask(ROIidx)))
      disp('Handling neuron overlap')

      % There is overlap, handle this carefully...

      % Pad the old neurons with one pixel, then only add those pixels
      % that are not already marked by this padded mask. This will leave
      % a one pixel boundary to the new neurons.

      overlapIdx = ROIidx(find(paddedMask(ROIidx)));
      ROImask(overlapIdx) = 0;

      % Keep only largest remaining component
      ROImask = largestComponent(ROImask);
    end

    newMask = double(oldMask + ROImask > 0);


  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %
  % This function tries to separate neurons that have been merged together
  % for whatever reason into one. It does so by first eroding the image
  % and seeing if any neurons break up into two components, those are then
  % split into multiple neurons.
  %

  function newMask = separateClusteredNeurons(oldMask)

    % Number each neuron
    oldMaskLabeled = bwlabel(oldMask);

    % Erode the neurons to see if they separate into multiple components
    disk = strel('disk',3);
    erodeMask = imerode(oldMask,disk);

    % Check which neuron each component belonged to
    s = regionprops(bwconncomp(erodeMask),'centroid');
    centroids = round(cat(1,s.Centroid));
    neuronId = zeros(length(centroids),1);
    markSplit = zeros(length(centroids),1);

    for i = 1:size(centroids,1)
      neuronId(i) = oldMaskLabeled(centroids(i,2),centroids(i,1));
    end

    % Did the erode separate any neurons into two components?
    for i = 1:length(neuronId)
      idx = find(neuronId == neuronId(i));
      if(numel(idx) > 1)
        markSplit(idx) = 1;
      end
    end

    splitIdx = find(markSplit);
    splitId = neuronId(splitIdx);

    uId = unique(splitId);

    newMask = oldMask;
    for i = 1:length(uId)
      % Clear the neurons that will be split
      newMask(find(oldMaskLabeled == uId(i))) = 0;
    end

    for i = 1:length(uId)
      [y,x] = find(oldMaskLabeled == uId(i));

      % Calculate the distance for each... 
      idx = splitIdx(find(splitId == uId(i)));
      d = zeros(length(idx),length(x));
      for j = 1:length(idx)
	d(j,:) = sqrt((x-centroids(idx(j),1)).^2+(y-centroids(idx(j),2)).^2);
      end

      [vals,memberId] = sort(d,1);
      memberId = memberId(1,:);

      uMemId = unique(memberId);

      for j = 1:length(uMemId)
	idx = find(memberId == uMemId(j));
        ROImask = zeros(size(newMask));

        for k=1:length(idx)
  	  ROImask(y(idx(k)),x(idx(k))) = 1;
        end

        newMask = addROItoMask(newMask,ROImask);
      end
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function defineRegionOfInterest(source, event)

    disp('Select ROI to analyse')
    set(handles.fig,'CurrentAxes',handles.plotLeft)

    bw = roipoly();

    filterIdx = ones(size(data.putativeCenter,1),1);

    for i = 1:length(filterIdx)
      if(~bw(data.putativeCenter(i,2),data.putativeCenter(i,1)))
        % Center outside ROI, remove
        filterIdx(i) = 0;
      end
    end

    data.putativeCenter = data.putativeCenter(find(filterIdx),:);
    showImage();

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %%% Time to do the work, detect the neurons

  function detectEdgesButton(source, eventData)

    % Check that an image is loaded before trying to detect
    if(~isempty(data.img))

      tic % Check time it takes

      % Mark the button as red, to avoid accidentally pressing it
      set(handles.detectEdges, 'BackgroundColor', [1 0 0])

      detectNeurons();
      updateConnectivityInfo();
      saveStateForUndo(' detect neurons');     
      showImage();
      showEdgeButtons();

      % Now we add the save button, since there is something to save
      if(isempty(handles.menuItemSave))

        handles.menuItemSave = uimenu(handles.menuFile, ...
 		 		      'Label','save Mask', ...
				      'Interruptible', 'off', ...
				      'Callback', @saveData);
      end

      toc
    else
      set(handles.detectEdges,'String','Patience, load first!');
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function markPia(source, event)

    filterMask(detection.minSize);
    updateConnectivityInfo();

    sliceImg = interp1([img.intensityLow img.intensityHigh], ...
		       [0 1], ...
		       data.img(:,:,data.center));
    sliceImg(data.img(:,:,data.center) < img.intensityLow) = 0;
    sliceImg(data.img(:,:,data.center) > img.intensityHigh) = 1;

    centroid = cat(1,data.neuronComponentsProps.Centroid);
    pixelIdxList = data.neuronComponents.PixelIdxList;

    [data.piaDist,data.piaPosition] ...
      = EvA_piaHelper(sliceImg, centroid, pixelIdxList, data.xRes, data.yRes);

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function updateConnectivityInfo()
    % Calculate connectivity for the neurons we finally settled for
    data.neuronComponents = bwconncomp(data.neuronMask);
    data.neuronComponentsProps = ...
    regionprops(data.neuronComponents, 'Area', 'Centroid');

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % This function is used to sanitise the input, we require that
  % it is a number between minVal and maxVal, and we can also
  % require it to be an integer if we want.
  function [newVal,modFlag] = sanitiseInput(inputString, oldVal, ...
					    minVal, maxVal, integerFlag)

    if(isnan(integerFlag))
      % We allow NaN, was it NaN?
      if(strcmpi(inputString,'NaN'))
        newVal = NaN;
        modFlag = 0;
        return
      else
        % No NaN, allow integers or reals...
	integerFlag = false;
      end
    end

    readVal = str2num(inputString);
    modFlag = 0;

    if(isempty(readVal))
      % We end up here if user types in letters instead of numbers
      newVal = oldVal;
      modFlag = 1;     
    else
      if(integerFlag)
	newVal = round(readVal);
      else
        newVal = readVal;
      end     
 
      newVal = max(minVal, newVal);
      newVal = min(maxVal, newVal);

      % Mark that we changed the input when sanitising it
      if(readVal ~= newVal)
        modFlag = 1;
      end
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function changeCenterDetectionSettings(source, eventData)

    prompt = { 'Fraction for lowest pixel intensity filtered (0-1)', ...
	       'Minimal distance between putative neurons', ...
               'Extra frames around center to use (+/- offset)', ...
               'Smoothing of image used for center detection', ...
               'Background removal (on/off)'};

    tmpBG = 'off';
    if(detection.useBGremoval)
      tmpBG = 'on';
    end

    defaultVal = { num2str(detection.putativeThreshold), ...
		   num2str(detection.minNeuronDist), ...
                   num2str(detection.Zspacing), ...
		   num2str(detection.smoothing), ...
                   tmpBG};
		   
    dialogName = 'Center detection parameters';

    numLines = 1;

    answers = inputdlg(prompt, dialogName, numLines, defaultVal);

    if(~isempty(answers))

      [detection.putativeThreshold, modFlag1] = ...
	sanitiseInput(answers{1}, detection.putativeThreshold, ...
		      1e-4, 1, false);
      [detection.minNeuronDist, modFlag2] = ...
	sanitiseInput(answers{2}, detection.minNeuronDist, ...
		      2, 20, true);
      [detection.Zspacing, modFlag3] = ...
	sanitiseInput(answers{3}, detection.Zspacing, ...
		      0, 20, true);

      [detection.smoothing, modFlag4] = ...
	sanitiseInput(answers{4}, detection.smoothing, ...
		      0.1, 20, false);

      modFlag5 = 1; % Indicate something was wrong with input
      switch(answers{5})
        case 'on'
          detection.useBGremoval = 1;
          modFlag5 = 0;
        case 'off'
  	  detection.useBGremoval = 0;
          modFlag5 = 0;
        otherwise
          % Keep modFlag5 = 1
      end

      if(modFlag1 | modFlag2 | modFlag3 | modFlag4 | modFlag5)

        warnMsg = sprintf(['The algorithm works in two steps:\n' ...
			   'First local maximas are located in the ' ...
			   'center frame. ' ...
                           'These center points must be larger than ' ...
                           'a %d %% of the pixels, and can be no ' ...
			   'closer spaced than %d pixels.' ...
                           'Using frames around center (+/-%d). ' ...
                           'The image is first smoothed with a gaussian ' ... 
			   'with std=%.1f.\n' ...
                           'The second step is the edge detection.'], ... 
			  detection.putativeThreshold*100, ...
			  detection.minNeuronDist, ...
			  detection.Zspacing, ...
			  detection.smoothing);
		   
        uiwait(warndlg(warnMsg, 'Input sanitation','modal'));

      end

      if(detection.Zspacing == 0)
	detection.useZspacing = 0;
      end

      updateToggleZGUI()
      updateBGGUI();

      if(~isempty(data.img))
        findNeuronCenters();

        data.neuronMask = zeros(size(data.neuronMask));
        updateConnectivityInfo(); 
        saveStateForUndo('new centers');

        showCenterButtons()
        showImage();
      end
    end

    updatePutativeThresholdGUI();
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function changeEdgeDetectionSettings(source, eventData)

    prompt = { 'Radie of detection sphere placed around neurons', ...
	       'Vertex resolution for detection sphere', ...
	       'Number of grid points per radial line', ...
	       'Minimal edge threshold (0-1)', ...
	       'Maximal edge threshold (0-1, NaN for auto)', ...
	       'Number of threshold steps', ...
	       'Minimal neuron radie (micrometer) (used for volume)', ...
	       'Maximum neuron radie (micrometer) (used for volume)', ...
               'Smallest area in center plane (micrometer^2)', ...
	       'Use largest drop as threshold'};

    tmpMinRadie = (detection.minVolume*3/(4*pi))^(1/3);
    tmpMaxRadie = (detection.maxVolume*3/(4*pi))^(1/3);

    defaultVal = { num2str(detection.maxR), ...
		   num2str(detection.nVert), ...
		   num2str(detection.nGrid), ...
		   num2str(detection.minEdgeThresh), ...
		   num2str(detection.maxEdgeThresh), ...
		   num2str(detection.nEdgeSteps), ...
		   num2str(tmpMinRadie), ...
                   num2str(tmpMaxRadie), ...
                   num2str(detection.minPlaneArea), ...
		   num2str(detection.autoThreshold) };
		   
    dialogName = 'Edge detection parameters';

    numLines = 1;

    answers = inputdlg(prompt, dialogName, numLines, defaultVal);

    if(~isempty(answers))

      [detection.maxR, modFlag1] = ...
	sanitiseInput(answers{1}, detection.maxR, ...
					    5, 50, true);
      [detection.nVert, modFlag2] = ...
	sanitiseInput(answers{2}, detection.nVert, ...
					    5, 50, true);
      [detection.nGrid, modFlag3] = ...
	sanitiseInput(answers{3}, detection.nGrid, ...
					    5, 50, true);
      [detection.minEdgeThresh, modFlag4] = ...
	sanitiseInput(answers{4}, detection.minEdgeThresh, ...
		      0, 1, false);
      [detection.maxEdgeThresh, modFlag5] = ...
	sanitiseInput(answers{5}, detection.maxEdgeThresh, ...
		      0, 1, NaN);
      [detection.nEdgeSteps, modFlag6] = ...
	sanitiseInput(answers{6}, detection.nEdgeSteps, ...
					    2, 50, true);
      [tmpMinRadie, modFlag7] = ...
	sanitiseInput(answers{7}, tmpMinRadie, ...
		      0, 20, false);
      detection.minVolume = 4*pi*tmpMinRadie^3/3;

      [tmpMaxRadie, modFlag8] = ...
	sanitiseInput(answers{8}, tmpMaxRadie, ...
		      3, 650, false);
      detection.maxVolume = 4*pi*tmpMaxRadie^3/3;

      [detection.minPlaneArea, modFlag9] = ...
	sanitiseInput(answers{9}, detection.minPlaneArea, ...
					    1, 100, false);

      [detection.autoThreshold,modFlag10] = ...
	sanitiseInput(answers{10},detection.autoThreshold,0,1,true);

    if(modFlag1 | modFlag2 | modFlag3 | modFlag4 | modFlag5 ...
       | modFlag6 | modFlag7 | modFlag8 | modFlag9 | modFlag10)

        warnMsg = sprintf(['The algorithm works in two steps:\n' ...
			   'The first step locates putative ' ...
                           'neuron centers.\n', ...
			   'In the second phase a sphere is placed ' ...
                           'around all centers. This sphere has a ' ...
                           'radie of %d micrometers. ' ...
                           'The algorithm then tries to find the ' ...
			   'best radie using a threshold between ' ...
			   '%.3f and %.3f (in %d steps). ' ...
	        	   'To be accepted as a neuron ' ...
                           'the volume has to be between ' ...
                           '%.0f and %.0f qubic micrometers. '...
                           'Minimal area in center plane is %.0f ' ...
                           'square micrometers.'], ...
			  detection.maxR, ...
			  detection.minEdgeThresh, ...
			  detection.maxEdgeThresh, ...
			  detection.nEdgeSteps, ...
			  detection.minVolume, ...
			  detection.maxVolume, ...
			  detection.minPlaneArea);
		   
        uiwait(warndlg(warnMsg, 'Input sanitation','modal'));

      end

    end

    updateMinEdgeThresholdGUI();

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function changeImageResolutionSettings(source, eventData)


    prompt = { 'X resolution (micrometers/pixel)', ...
	       'Y resolution (micrometers/pixel)', ...
               'Z resolution (micrometers/pixel)', ...
               'Sampling frequency (Hz)'};


    defaultVal = { num2str(data.xRes), ...
                   num2str(data.yRes), ...
                   num2str(data.zRes), ...
                   num2str(data.freq)};
		   
    dialogName = 'Image pixel resolution';

    numLines = 1;

    answers = inputdlg(prompt, dialogName, numLines, defaultVal);

    if(~isempty(answers))

      [data.xRes, modFlag1] = ...
	sanitiseInput(answers{1}, data.xRes, 0.01, 5, false);
      [data.yRes, modFlag2] = ...
	sanitiseInput(answers{2}, data.yRes, 0.01, 5, false);
      [data.zRes, modFlag3] = ...
	sanitiseInput(answers{3}, data.zRes, 0.01, 5, false);
      [data.freq, modFlag4] = ...
	sanitiseInput(answers{4}, data.freq, 1, 100, false);

      if(modFlag1 | modFlag2 | modFlag3 | modFlag4)

        warnMsg = sprintf(['Size of voxels in micrometers:\n' ...
		           '%.3fx%.3fx%.3f micrometers\n' ...
			   'Sampled at %.1fHz'], ...
                          data.xRes, data.yRes, data.zRes, data.freq);
		   
        uiwait(warndlg(warnMsg, 'Input sanitation','modal'));

      end

    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function toggleGrid(source, eventData)
    if(img.showGrid)
      img.showGrid = 0;
      set(handles.toggleGrid,'Checked','off');
    else
      img.showGrid = 1;
      set(handles.toggleGrid,'Checked','on');
    end

    showImage();
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function resetSettings(source, eventData)

    % Reset settings
    doneFlag = detection.done;
    detection = defaultDetection;
    detection.done = doneFlag;

    % Restore GUI
    set(handles.centerThresh,'Value', detection.putativeThreshold)
    updateToggleZGUI();
    updateBGGUI();
    updateMinEdgeThresholdGUI();

    disp('Settings restored to default.')

    if(~isempty(data.img) & ~detection.done)

      findNeuronCenters(); 

      data.neuronMask = zeros(size(data.neuronMask));
      updateConnectivityInfo(); 
      saveStateForUndo(' detection restart');     
      showImage();

    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function toggleAutoEdge(source, eventData)
    if(strcmpi(get(handles.menuItemEdgeAuto,'Checked'),'on'))
      detection.autoThreshold = 0;
      set(handles.menuItemEdgeAuto,'Checked','off');
    else
      detection.autoThreshold = 1;
      set(handles.menuItemEdgeAuto,'Checked','on');
    end

    % Make sure the visibility and text is correct
    updateMinEdgeThresholdGUI(); 

  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function undoAction(source, eventData)
    if(editInfo.undoIdx > 1)
      editInfo.undoIdx = editInfo.undoIdx - 1;
      data.neuronMask = editInfo.undo{editInfo.undoIdx};

      % Restore connectivity info for old mask
      updateConnectivityInfo();

      % Show the result.
      showImage();

      % We just decreased the undo counter, are there any actions
      % left to undo, if so update the menu accordingly.
      if(editInfo.undoIdx > 1)
        undoLabel = sprintf('Undo %s', ...
			    editInfo.actionType{editInfo.undoIdx});
      else
        undoLabel = 'No actions to undo';
      end

      set(handles.menuItemUndo, 'Label', undoLabel)
    else
      disp('We can not undo what we have not yet done. Sorry!')
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function saveStateForUndo(lastActionType)

    % Only add undo information if something actually changed
    if(isempty(editInfo.undo) | nnz(editInfo.undo{end} - data.neuronMask))

      editInfo.undoIdx = editInfo.undoIdx + 1;
      editInfo.undo{editInfo.undoIdx} = data.neuronMask;
      editInfo.actionType{editInfo.undoIdx} = lastActionType;

      set(handles.menuItemUndo,'Label',sprintf('Undo %s', lastActionType))

    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function showCenterButtons()

    % GUIs shown after the tiff image is loaded and
    % centers are detected.
    set(handles.detectEdges,'Visible','on')
    set(handles.centerThresh,'Visible','on')
    set(handles.threshText,'Visible','on')
    set(handles.Ztext,'Visible','on')
    set(handles.includeZdepth,'Visible','on')
    set(handles.BGtext,'Visible','on')
    set(handles.useBGremoval,'Visible','on')
    set(handles.defineROI,'Visible','on')

    set(handles.histText,'Visible','on')
    set(handles.zSlider,'Visible','on')
    set(handles.zText,'Visible','on')

    set(handles.edgeText,'Visible','off')
    set(handles.edgeMinThresh,'Visible','off')
    set(handles.markPia,'Visible','off')
    set(handles.splitNeurons,'Visible','off')

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function showEdgeButtons()

    % GUIs shown after edges have been detected
    set(handles.detectEdges,'Visible','on')

    set(handles.centerThresh,'Visible','off')
    set(handles.threshText,'Visible','off')
    set(handles.Ztext,'Visible','off')
    set(handles.includeZdepth,'Visible','off')
    set(handles.BGtext,'Visible','off')
    set(handles.useBGremoval,'Visible','off')
    set(handles.defineROI,'Visible','off')

    set(handles.edgeText,'Visible','on')
    set(handles.edgeMinThresh,'Visible','on')

    % Make sure the visibility and text is correct
    updateMinEdgeThresholdGUI(); 

    set(handles.markPia,'Visible','on')
    set(handles.splitNeurons,'Visible','on')

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function filterMask(minSize)

    for iFilt = 1:length(data.neuronComponents.PixelIdxList)
      if(numel(data.neuronComponents.PixelIdxList{iFilt}) < minSize)
        for iPixel = 1:length(data.neuronComponents.PixelIdxList{iFilt})
          data.neuronMask(data.neuronComponents.PixelIdxList{iFilt}) = 0;
        end
      end
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  function splitNeurons(source, event)
    saveStateForUndo(' split neurons');     
    data.neuronMask = separateClusteredNeurons(data.neuronMask);
    updateConnectivityInfo();
    showImage();

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  
  
  function saveConfig()
    
    fprintf('Saving parameters to %s\n', configFile)
    pars = [];
    
    allPars = {saveDataPars,saveImgPars,saveDetectionPars};
    parType = {'data','img','detection'};
    
    for i = 1:numel(parType)
      for j = 1:numel(allPars{i})
        try
          cmd = sprintf('pars.%s.%s = %s.%s;', ...
                        parType{i}, allPars{i}{j}, parType{i}, allPars{i}{j});
          eval(cmd);
        catch e
          getReport(e)
          keyboard
        end
      end
    end
    
    save(configFile, 'pars');
    
  end
  
  function loadConfig()

    try
      tmp = load(configFile);
      pars = tmp.pars;
    catch e
      fprintf('Unable to load %s\n', configFile)
      return
    end

    allPars = {saveDataPars,saveImgPars,saveDetectionPars};
    parType = {'data','img','detection'};

    for i = 1:numel(parType)
      for j = 1:numel(allPars{i})
          
        try
          compareCmd = sprintf('%s.%s == pars.%s.%s', ...
                               parType{i}, allPars{i}{j}, parType{i}, allPars{i}{j});       

          if(~eval(compareCmd))
            % Print changes
            fprintf('Set %s.%s = %f (default: %f)\n', ...
                    parType{i}, allPars{i}{j}, ...
                    eval(sprintf('pars.%s.%s', parType{i}, allPars{i}{j})), ...
                    eval(sprintf('%s.%s', parType{i}, allPars{i}{j})))
            
            cmd = sprintf('%s.%s = pars.%s.%s;', ...
                          parType{i}, allPars{i}{j}, parType{i}, allPars{i}{j});
            eval(cmd);
          end
        catch e
          getReport(e)
          % Continue...
          keyboard
        end
      end
    end
    
    
  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
end


