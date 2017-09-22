%
% Event Analyser
%
% EvA_inspect.m
% Inspect neuron traces
%
% Johannes Hjorth
% Julia Dawitz
% Rhiannon Meredith
%
% For questions or suggestions:
% Johannes Hjorth, hjorth@kth.se
%
% Important:
% This script requires detectEventsTrace.m to run.
% To generate input for EvA_inspect.m first run EvA_extract.m
%
% This matlab code reads in a predefined mask from file
% then uses that to extract the traces from a user specified 
% tiff-stack. The traces are then presented to the user.
%
%
% CONCERNS
%
%
%
% Things to add:
%
%
% * Weight the neurons pixels based on the distance from the centroid 
% * Do histogram over average pixel intensities, and standard deviation
%   of the pixels. Allow selection of the pixels by clicking in histogram.
% * Alternatively, weight the pixels by the distance to the centroid.
%
% * Add status textbox to inform user
%
% * Test plotting cross correlation as a function of distance to centroid
%   

function EvA_inspectTraces()

  close all

  version = '2011-11-30';

  % The current trace we are showing
  iTrace = 0;
  oldTrace = 0;

  data.numNeurons = 0;
  data.numFrames = 0;
  data.meanTrace = []; 
  data.relTrace = [];
  dataMask.neuronMask = [];
  dataMask.pixelList = [];
  dataMask.file = [];
  data.firstFrame = [];
  data.traceBaseline = [];
  data.eventStartIdx = {};
  data.traceFile = {};
  data.primaryEventIdx = {};

  dispInfo.showFirstFrame = true;
  dispInfo.showMask = true;
  dispInfo.onlyShowMeanTrace = true; % !!! Set oldTrace = 0
  dispInfo.uncheckedImports = [];

  detection.nStdThresh = 1; % Old default was 2
  detection.nDotsCheck = 5;
  detection.reqIntensityDrop = 0.1;
  detection.medianFilterWidth = 100;
  detection.pThreshDetect = [0.2 1e-3 1e-4 1e-5];

  detection.slopeDt = 2;

  % Reduction of peak before end of event is detected
  % if ZERO, we use the old version of crossing the baseline
  detection.endOfEventThreshold = 0.1;

  % How many frames empty before event to call it a new burst
  detection.burstThreshold = 5;

  cfgFileName = 'EvA_inspectConfig.mat';

  saveDetectionStats = true;
  % This is used to assess how well the different iterations perform
  detectionStats = struct();
  
  
  % Load old saved detection config if it exists
  loadDetectionConfig();

  %%% Lets define the GUI

  handles.fig          = figure('Name', ...
                                'Event Analyser (EvA) - Inspect Traces', ...
                                'MenuBar','none', ...
                                'Toolbar', 'figure', ...
                                'WindowButtonDownFcn', ...
                                @MouseButtonDownHandler, ...
                                'WindowKeyPressFcn', ...
                                @KeyPressHandler, ...
                                'Position', [50 50 1200 700]);
  

  % This figure shows the trace
  handles.trace        = axes('Units','Pixels', ...
                              'Position',[50 320 1100 350]);
  
  % This figure shows the slice with neurons marked out
  handles.slice        = axes('Units','Pixels', ...
                              'Position',[50 40 250 250]);
  
  % This figure shows the events (centered on start point)
  handles.areaInspect = axes('Units','Pixels', ...
                             'Position',[600 180 370 110]);
  
  handles.slopeInspect = axes('Units','Pixels', ...
			     'Position',[600 40 370 110]);
  
  handles.eventInspect = axes('Units','Pixels', ...
                              'Position',[330 40 240 140]);
  
  
  % Pushbuttons to navigate between traces
  handles.next         = uicontrol('Style','pushbutton', ...
                                   'String','<html><u>N</u>ext trace</html>', ...
                                   'Interruptible', 'off', ...
                                   'Position',[430,260,80,30], ...
                                   'Callback', @nextTrace);
  
  handles.prev         = uicontrol('Style','pushbutton', ...
                                   'String','<html><u>P</u>rev trace</html>', ...
                                   'Interruptible', 'off', ...
                                   'Position',[330,260,80,30], ...
                                   'Callback', @prevTrace);
  
  handles.traceNum     = uicontrol('Style','edit', ...
                                   'String', num2str(iTrace), ...
                                   'Interruptible', 'off', ...
                                   'Position', [530 260 40 30], ...
                                   'Callback', @setTrace);
  
  
  handles.detect       = uicontrol('Style', 'pushbutton', ...
                                   'String', 'Detect events in slice', ...
                                   'Interruptible', 'off', ...
                                   'Position', [1000 260 150 30], ...
                                   'Callback', @detectEventsButton);
  
  handles.reDetect     = uicontrol('Style','pushbutton', ...
                                   'String','<html><u>R</u>e-detect trace</html>', ...
                                   'Interruptible', 'off', ...
                                   'Position',[1000,220,150,30], ...
                                   'Callback', @redetectEventsHighButton); % Changed!!
  
  handles.delete       = uicontrol('Style','pushbutton', ...
                                   'String','<html><u>D</u>elete trace events</html>', ...
                                   'Interruptible', 'off', ...
                                   'Position',[1000,180,150,30], ...
                                   'Callback', @deleteEvents);
  
  handles.trimEvents   = uicontrol('Style','pushbutton', ...
                                   'String','<html><u>T</u>rim trace events</html>', ...
                                   'Interruptible', 'off', ...
                                   'Position',[1000,140,150,30], ...
                                   'Callback', @trimEvents);
  
  
  
  handles.fileNames    = uicontrol('Style', 'text', ...
                                   'String', '', ...
                                   'Fontsize', 8, ...
                                   'BackgroundColor', get(gcf,'color'), ...
                                   'Position', [1000 30 150 100]);
  
  
  handles.include      = uicontrol('Style', 'checkbox', ...
                                   'Value', 0, 'Max', 1, ...
                                   'Interruptible', 'off', ...
                                   'Position', [330 225 20 20], ...
                                   'Callback', @includeTrace);
  
  handles.includeText = uicontrol('Style', 'text', ...
                                  'String', 'Include trace', ...
                                  'Fontsize', 12, ...
                                  'BackgroundColor', get(gcf,'color'), ...
                                  'HorizontalAlignment','left', ...
                                  'Position', [360 225 210 20]);
  
  handles.special      = uicontrol('Style', 'checkbox', ...
                                   'Value', 0, 'Max', 1, ...
                                   'Interruptible', 'off', ...
                                   'Position', [330 195 20 20], ...
                                   'Callback', @specialTrace);
  
  handles.specialText = uicontrol('Style', 'text', ...
                                  'String', 'I am special!', ...
                                  'Fontsize', 12, ...
                                  'BackgroundColor', get(gcf,'color'), ...
                                  'HorizontalAlignment','left', ...
                                  'Position', [360 195 210 20]);
  
  handles.credits = uicontrol('Style', 'text', ...
                              'String', 'Johannes Hjorth, 2010', ...
                              'HorizontalAlignment', 'right', ...
                              'Foregroundcolor', 0.7*[1 1 1], ...
                              'Backgroundcolor', get(gcf,'color'), ...
                              'Position', [1085 5 110 15], ...
                              'Fontsize',8);
  
  
  % Make the figure resizeable by using normalisation
  set([handles.fig, handles.trace, handles.slice, ...
       handles.areaInspect, handles.slopeInspect, handles.eventInspect, ...
       handles.next, handles.prev, handles.traceNum, handles.credits, ...
       handles.detect, handles.reDetect, handles.delete, ...
       handles.fileNames, handles.include, handles.includeText, ...
       handles.special, handles.specialText, handles.trimEvents], ...
      'Units','Normalized')
  
  
  % Load and save menu item
  handles.menuFile         = uimenu(handles.fig,'Label','File');
  
  handles.menuItemLoadMask = uimenu(handles.menuFile, ...
                                    'Label','Load mask', ...
                                    'Interruptible', 'off', ...
                                    'Callback', @loadNeuronMask);
  
  handles.menuItemLoadTiff = uimenu(handles.menuFile, ...
                                    'Label','Load traces', ...
                                    'Interruptible', 'off', ...
                                    'Callback', @loadTiffTraces);
  
  handles.menuItemSave = uimenu(handles.menuFile, ...
                                'Label','Save Traces', ...
                                'Interruptible', 'off', ...
                                'Callback', @saveTraces);
  
  handles.menuItemImport = uimenu(handles.menuFile, ...
                                  'Label','Import event times', ...
				'Interruptible', 'off', ...
                                  'Callback', @importEventTimes);
  
  handles.menuItemLoadState = uimenu(handles.menuFile, ...
                                     'Label', 'Load trace state' , ...
                                     'Interruptible', 'off', ...
                                     'Callback', @loadState);
  
  handles.menuItemLoadState = uimenu(handles.menuFile, ...
                                     'Label', 'Save trace state' , ...
                                     'Interruptible', 'off', ...
                                     'Callback', @saveState);
  
  
  % Settings menu
  handles.menuSettings  = uimenu(handles.fig,'Label','Settings');
  
  
  handles.menuItemEventSetting  = uimenu(handles.menuSettings, ...
                                         'Label','Event detection', ...
                                         'Interruptible', 'off', ...
                                         'Callback', ...
                                         @changeEventDetectionSettings);
  
  handles.menuItemPiaMask  = uimenu(handles.menuSettings, ...
                                    'Label','Change pia mask', ...
                                    'Interruptible', 'off', ...
                                    'Callback', ...
                                    @changePiaMask);
  
  handles.menuItemShave  = uimenu(handles.menuSettings, ...
                                  'Label','Remove frames', ...
                                  'Interruptible', 'off', ...
                                  'Callback', ...
                                  @shaveFrames);
  
  handles.menuItemInvert  = uimenu(handles.menuSettings, ...
                                   'Label','Invert trace', ...
                                   'Interruptible', 'off', ...
                                   'Callback', ...
                                   @invertTrace);
  
  
  
  % View menu, what is displayed in trace and slice
  handles.menuView           = uimenu(handles.fig,'Label','View');
  
  handles.menuItemFirstFrame = uimenu(handles.menuView, ...
                                      'Label','View first frame', ...
                                      'Checked','on', ...
                                      'Interruptible', 'off', ...
                                      'Callback', @toggleFirstFrame);
  
  handles.menuItemMask = uimenu(handles.menuView, ...
                                'Label','View neuron mask', ...
                                'Checked','on', ...
                                'Interruptible', 'off', ...
                                'Callback', @toggleMask);
  
  handles.menuItemRaw  = uimenu(handles.menuView, ...
                                'Label','Only view raw trace', ...
                                'Checked','on', ...
                                'Interruptible', 'off', ...
                                'Callback', @toggleRaw);
  
  
  handles.menuDebug = uimenu(handles.fig,'Label','Debug');
  handles.menuItemDebug =  uimenu(handles.menuDebug, ...
                                  'Label','Keyboard', ...
                                  'Interruptible', 'off', ...
                                  'Callback', @runDebug);
  
  handles.menuItemDebug =  uimenu(handles.menuDebug, ...
                                  'Label','Cheat', ...
                                  'Interruptible', 'off', ...
                                  'Callback', @lookForSavedTimes);
  
  
  
  handles.eventZoomId = [];
  
  
  % Right click menu for events
  handles.contextMenu = uicontextmenu;
  
  uimenu(handles.contextMenu, ...
         'Label', 'Add event (auto)',...
         'Interruptible', 'off', ...
         'Callback',@addEventCallback);
  
  uimenu(handles.contextMenu, ...
         'Label', 'Add event (click end)',...
         'Interruptible', 'off', ...
         'Callback',@addEvent2Callback);
  
  uimenu(handles.contextMenu, ...
         'Label', 'Delete event', ...
         'Interruptible', 'off', ...
         'Callback', @deleteEventCallback);
  
  uimenu(handles.contextMenu, ...
         'Label', 'Move start', ...
         'Interruptible', 'off', ...
         'Callback', @moveStartCallback);
  
  uimenu(handles.contextMenu, ...
         'Label', 'Split event', ...
         'Interruptible', 'off', ...
         'Callback', @splitEventCallback);
  
  
  uimenu(handles.contextMenu, ...
         'Label', 'Add artifact', ...
         'Interruptible', 'off', ...
         'Callback', @addArtifactCallback);
  
  uimenu(handles.contextMenu, ...
         'Label', 'Add artifact (all traces)', ...
         'Interruptible', 'off', ...
         'Callback', @addArtifactALLCallback);
  
  uimenu(handles.contextMenu, ...
         'Label', 'Delete artifact', ...
         'Interruptible', 'off', ...
         'Callback', @deleteArtifactCallback);
  
  
  handles.contextMenuEnd = uicontextmenu;
  uimenu(handles.contextMenuEnd, ...
         'Label', 'Move end to next crossing',...
         'Interruptible', 'off', ...
         'Callback',@moveEndCallback);
  
  uimenu(handles.contextMenuEnd, ...
         'Label', 'Delete event', ...
         'Interruptible', 'off', ...
         'Callback', @deleteEventCallback);
  
  uimenu(handles.contextMenuEnd, ...
         'Label', 'Split event', ...
         'Interruptible', 'off', ...
         'Callback', @splitEventCallback);
  
  
  
  
  % Some dirty tricks to get the zoom and pan tools
  % Set up toolbar, only keep zoom in, zoom out and pan
  
  handles.toolbar = findall(handles.fig,'Type','uitoolbar');
  oldChild = allchild(handles.toolbar);
  
  for i=1:length(oldChild)
    tmp = get(oldChild(i),'Tag');
    
    switch(tmp)
      case 'Exploration.ZoomIn'
      case 'Exploration.ZoomOut'
      case 'Exploration.Pan'
        % Do nothing, we want to keep these
      otherwise 
        delete(oldChild(i));         % Remove the rest
    end
  end
  
  % Set default zoom mode to make Julia happy
  handles.zoom = zoom(gcf);
  set(handles.zoom,'motion','horizontal')
  
  showPhoto()
  
  %%%%%%%%%


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %%% Callback functions

  function runDebug(source, event)
    disp('Type return to exit debug mode')
    keyboard
  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function lookForSavedTimes(source, event)
    try
      data.eventStartIdx = dataMask.eventStartIdx;
      data.eventEndIdx = dataMask.eventEndIdx;
      
      for i = 1:length(data.eventStartIdx) 
        data.eventP{i} = NaN*data.eventStartIdx{i};
      end
      
      % 4. Recalculate baseline
      
      for i=1:data.numNeurons
        calculateBaseline(i);
      end
      
      % 5. Recalculate event properties
      
      for i=1:data.numNeurons
        calculateEventProperties(i);        
      end
      
      % 6. Show the new traces
      
      setShowRelativeTrace();
      
      plotTrace();
      plotEventInspect();
      showSlice();
      
      
    catch exception
      getReport(exception)
      disp('Cheating failed... no stored spike times. Please restart EvA.')
      keyboard
    end
    
  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function saveState(source, eventData)
    
    if(~isempty(data))
      
      if(isempty(data.traceFile))
        saveFileSuggestion = strrep(dataMask.file,'.tif','');
      else
        saveFileSuggestion = strrep(data.traceFile{1},'.tif','');
      end
      
      saveFileSuggestion = strrep(saveFileSuggestion,'.tiff','');
      saveFileSuggestion = strrep(saveFileSuggestion,'.TIF','');
      
      %saveFileSuggestion = strcat(saveFileSuggestion, ...
      %				  strcat(datestr(now(), '-yyyy-mm-dd-HH:MM'), ...
      %					 '-state.mat'))
      
      saveFileSuggestion = strcat(saveFileSuggestion, ...
                                  strcat(datestr(now(), '-yyyy-mm-dd-HHMM'), ...
                                         '-state.mat'));
      
      
      saveThis = { 'data', 'dataMask', 'detection', 'iTrace', ...
                   'dispInfo' };
      
      
      % Recalculate, just to be on the safe side
      for i=1:data.numNeurons
        calculateEventProperties(i);        
      end
      
      uisave(saveThis, saveFileSuggestion)
      
    else
      disp('Nothing to save!')
    end
    
  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % Imports event times from a previously saved trace
  % Keeps only the neurons which have not had their mask changed
  function importEventTimes(source, eventData)
    
    if(isempty(data.traceFile))
      disp('You must have loaded mask and trace file(s) first.')
      return
    end

    if(isempty(data.eventStartIdx))
      detectEvents();
      return
    end
    
    [traceFile, tracePath] = uigetfile('*-trace.mat','Select old trace file');
    
    if(isequal(traceFile,0) | isequal(tracePath,0))
      return
    end
    
    oldData = load([tracePath traceFile]);
    oldData = oldData.saveData;
    
    % 1. Make sure the same data files are loaded
    if(length(data.traceFile) ~= length(oldData.traceFile))
      disp('Different number of tiff-stacks loaded.');
      return
    end
    
    allEqual = 1;
    
    for i = 1:length(data.traceFile)
      if(~isequal(data.traceFile{i},oldData.traceFile{i}))
        disp(sprintf('File %d: %s and %s are different files.', ...
                     i, data.traceFile{i}, oldData.traceFile{i}))
        allEqual = 0;
      end
    end
    
    if(~allEqual)
      disp('Aborting import.')
      return
    end
    
    % 2. Check which neurons have the same mask, what is their old number?
    curNeuronIdx = [];
    oldNeuronIdx = [];
    
    for i=1:length(dataMask.pixelList)
      idx = oldData.neuronMaskNumbered(dataMask.pixelList{i}(1));
      
      if(idx == 0)
        % No neuron was there before
        continue
      end
      
      if(isequal(unique(dataMask.pixelList{i}), ...
                 unique(oldData.pixelList{idx})))
        % We found a neuron match
        curNeuronIdx(end+1,1) = i;
        oldNeuronIdx(end+1,1) = idx;
      end
      
    end
    
    % 3. Import event start and end times (doesnt import artifacts)
    
    for i = 1:length(curNeuronIdx)
      curN = curNeuronIdx(i);
      oldN = oldNeuronIdx(i);
      
      data.eventStartIdx{curN}   = oldData.eventStartIdx{oldN};
      data.eventStartSlope{curN} = oldData.eventStartSlope{oldN};
      data.eventEndIdx{curN}     = oldData.eventEndIdx{oldN};
      data.eventPeakIdx{curN}    = oldData.eventPeakIdx{oldN};
      data.eventPeakValue{curN}  = oldData.eventPeakValue{oldN};
      data.eventArea{curN}       = oldData.eventArea{oldN};
      data.eventP{curN}          = oldData.eventP{oldN};
      data.primaryEventIdx{curN} = oldData.primaryEventIdx{oldN};
    end

    data.includeNeuron(curNeuronIdx) = oldData.includeNeuron(oldNeuronIdx);
    data.specialNeuron(curNeuronIdx) = oldData.specialNeuron(oldNeuronIdx);
    
    disp('Artifacts are not imported!')
    
    % 4. Recalculate baseline

    for i=1:data.numNeurons
      calculateBaseline(i);
    end

    % 5. Recalculate event properties
    
    for i=1:data.numNeurons
      calculateEventProperties(i);        
    end

    % 6. Show the new traces
    
    setShowRelativeTrace();
    
    plotTrace();
    plotEventInspect();
    showSlice();
    
    for i=1:length(curNeuronIdx)
      updatedIdx = curNeuronIdx(i);
      changedIdx = setdiff(1:data.numNeurons,curNeuronIdx);
      
      hold on
      plot(dataMask.centroid(updatedIdx,1), ...
           dataMask.centroid(updatedIdx,2),'y*')
      plot(dataMask.centroid(changedIdx,1), ...
           dataMask.centroid(changedIdx,2),'b*')
      
      hold off
      
    end
    
    dispInfo.uncheckedImports = changedIdx;
    
  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function loadState(source, eventData)
  
    [dataFile dataPath] = ...
        uigetfile({'*-state.mat','State file'; '*.mat','MAT-file'}, ...
                  'Select state file', ...
                  'MultiSelect','off');
    
    if(dataFile == 0)
      % User pressed cancel
      return;
    end
    
    oldData = load([dataPath dataFile]);
    
    data = oldData.data;
    dataMask = oldData.dataMask;
    
    prevDetection = detection;
    detection = oldData.detection;
    
    
    iTrace = oldData.iTrace;
    dispInfo = oldData.dispInfo;
    
    % Old versions of saved data does not have specialNeuron variable
    % check if it is there, if not, add it.
    try
      data.specialNeuron;
    catch
      data.specialNeuron = zeros(data.numNeurons,1);
    end
    
    try
      dispInfo.uncheckedImports;
    catch
      dispInfo.uncheckedImports = [];
    end
    
    try 
      detection.endOfEventThreshold;
    catch
      detection.endOfEventThreshold = prevDetection.endOfEventThreshold;
      fprintf('No detection setting, using end of event threshold %d\n', ...
              detection.endOfEventThreshold)
    end
    
    try
      detection.burstThreshold;
    catch
      detection.burstThreshold = prevDetection.burstThreshold;
      fprintf('Old state file, using burst threshold %d\n', ...
              detection.burstThreshold)
    end
    
    try
      data.primaryEventIdx;
    catch
      for i = 1:data.numNeurons
        classifyEvents(i);
      end
    end

    lookForDuplicates();
    
    if(dispInfo.onlyShowMeanTrace)
      set(handles.menuItemRaw,'checked','on')
    else
      set(handles.menuItemRaw,'checked','off')
    end
    
    oldTrace = 0;
    
    % Recalculate, just to be on the safe side
    for i=1:data.numNeurons
      calculateEventProperties(i);        
    end
    
    
    % Display the new data
    showSlice();
    plotTrace();
    plotEventInspect();
    
    checkSaturatedPixels();
    
  end

  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
  % Callback function used when the "Next trace" button is pressed
  % Moves to next trace and redraws figure

  function nextTrace(source, eventdata)
    %disp('Next trace called.')
    if(iTrace < length(dataMask.pixelList))
      iTrace = iTrace + 1;
    end
    
    showSlice();
    plotTrace();
    plotEventInspect();
  end
   
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % Callback function used when "Prev trace" button is pressed
  % Moves to previous trace and redraws figure

  function prevTrace(source, eventdata)
    %disp('Prev trace called.')
    if(iTrace > 1)
      iTrace = iTrace - 1;
    end
    
    showSlice();
    plotTrace();
    plotEventInspect();
  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % Callback function used when the user inputs a new trace number

  function setTrace(source, eventdata)
    
    tmp = str2num(get(handles.traceNum,'String'));
    
    if(isempty(tmp) | tmp < 1 | tmp > data.numNeurons)
      % Invalid value inputed, must be integer
      set(handles.traceNum,'String', sprintf('%.0f',iTrace));    
      return
    end
    
    
    iTrace = round(tmp);
    
    showSlice();
    plotTrace();
    plotEventInspect();
  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % Callback function to flag a trace for inclusion or deletion
  
  function includeTrace(source, eventdata)

    % Only allow inclusion if there is a trace
    if(data.numNeurons > 0)
      data.includeNeuron(iTrace) = get(handles.include,'Value');
    end
    
    showSlice();
    
  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  function specialTrace(source, eventdata)
    
  % Only allow inclusion if there is a trace
    if(data.numNeurons > 0)
      data.specialNeuron(iTrace) = get(handles.include,'Value');
    end

    showSlice();
    
  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % Callback to turn and off the display of pixel intensity for first slice
  function toggleFirstFrame(source, eventData)
    dispInfo.showFirstFrame = ~dispInfo.showFirstFrame;
    
    if(dispInfo.showFirstFrame)
      set(handles.menuItemFirstFrame,'checked','on');
    else
      set(handles.menuItemFirstFrame,'checked','off');
    end
    
    showSlice();
  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % Callback to turn and off the display of pixel intensity for first slice
  function toggleMask(source, eventData)
    dispInfo.showMask = ~dispInfo.showMask;
    
    if(dispInfo.showMask)
      set(handles.menuItemMask,'checked','on');
    else
      set(handles.menuItemMask,'checked','off');
    end
    
    showSlice();
  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function setShowRawTrace()
    set(handles.menuItemRaw,'checked','on')
    dispInfo.onlyShowMeanTrace = true;
    oldTrace = 0;
  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function setShowRelativeTrace()
    set(handles.menuItemRaw,'checked','off')
    dispInfo.onlyShowMeanTrace = false;
    oldTrace = 0;
  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function toggleRaw(source, eventData)
    if(~dispInfo.onlyShowMeanTrace)
      setShowRawTrace();
    else
      setShowRelativeTrace();
    end

    plotTrace();
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %%% Helper functions

  function loadNeuronMask(source, eventData)

    [dataFile dataPath] = ...
      uigetfile({'*-mask.mat','Mask file'; '*.mat','MAT-file'}, ...
                'Select neuron mask file', ...
                'MultiSelect','off');
    
    if(dataFile == 0)
      % User pressed cancel
      return;
    end

    tmp = load([dataPath dataFile]);
    dataMask = tmp.saveData;

    disp(sprintf('%s loaded.', dataFile))

    % Add the load tiff to the menu after mask is loaded
    % This is to avoid them being loaded in wrong order


    % We just loaded a new mask, remove save function until new
    % trace data have been loaded
    handles.menuItemSave = [];

    % Display the loaded slice and the trace of the first neuron
    iTrace = 1;
 
    % Clear previously loaded tiff-stacks with traces
    data = [];

    % Initialise variables
    data.numNeurons = dataMask.numNeurons;
    data.traceBaseline = [];

    % This variable indicates whether the neuron is included in
    % further analysis or not
    data.includeNeuron = ones(dataMask.numNeurons,1);

    % Allow marking of neurons as special
    data.specialNeuron = zeros(dataMask.numNeurons,1);


    data.traces          = {};
    data.eventStartIdx   = {};
    data.eventStartSlope = {};
    data.eventEndIdx     = {};
    data.eventPeakIdx    = {};
    data.eventPeakValue  = {};
    data.eventArea       = {};
    data.primaryEventIdx = {};

    data.traceFile = {};
    data.tracePath = {};

    for i=1:data.numNeurons
      data.traces{i}          = [];
      data.eventStartIdx{i}   = [];
      data.eventStartSlope{i} = [];
      data.eventEndIdx{i}     = [];
      data.eventPeakIdx{i}    = [];
      data.eventPeakValue{i}  = [];
      data.eventArea{i}       = [];
      data.eventP{i} = [];
      data.primaryEventIdx{i} = [];

      % Clear all artifacts
      data.artIdx{i} = [];

    end

    oldTrace = 0;
    data.numFrames  = 0;
    data.meanTrace  = []; 
    data.firstFrame = [];
    data.relTrace   = [];

    % Clear the old trace in case there was one loaded
    set(handles.fig,'CurrentAxes',handles.trace)    
    cla

    showSlice();
    plotTrace();
    plotEventInspect();
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function loadTiffTraces(source, eventData)

    if(isempty(dataMask.neuronMask))
      disp('Load neuron mask first')
      return;
    end

    % This concatenates to previous data

    % Ask the user for a tiff-file to read
    [tiffFile, tiffPath, fileType] = ...
        uigetfile({'*.tif','Select a tiff-stack'; ...
                   '*.stk','Select stk file'});

    if(tiffFile == 0)
      % User pressed cancel
      return;
    end


    if(isequal(tiffFile,0) | isequal(tiffPath,0))
      % No file selected to load
      return
    end

    waitBar = waitbar(0,sprintf('Loading %s and extracting neuron traces.',tiffFile));

    % Add to the existing frames
    frameOfs = data.numFrames;

    %%% Load the tiff-file %%%
    fileName = [tiffPath tiffFile];
    disp(sprintf('Loading %s', fileName))
    data.traceFile{end+1} = tiffFile;
    data.tracePath{end+1} = tiffPath;


    switch(fileType)
      case 1
        tiffInfo = imfinfo(fileName);
        data.height = tiffInfo(1).Height;
        data.width  = tiffInfo(1).Width; 
        data.numFrames = data.numFrames + length(tiffInfo);
        nNewFrames = length(tiffInfo);
        preloadMovie = [];
      case 2
        preloadMovie = tiffread(fileName);
        nNewFrames = length(preloadMovie);
        data.height = preloadMovie(1).height;
        data.width = preloadMovie(1).width;
        data.numFrames = data.numFrames + length(preloadMovie);

      otherwise
        disp('Load error, talk to Johannes')
        keyboard
    end

    % Make sure width and height matches!
    if(data.height ~= dataMask.height ...
       | data.width ~= dataMask.width)
      beep
      errordlg(['Size mismatch between trace and z-stack (check ' ...
                'height and width). Please restart EvA_inspectTraces.'],'Input error')
    end
      
    % Preallocate memory so that it is faster, mark the new as NaN
    % so we can easier see if something went wrong.
    for i=1:data.numNeurons
      data.traces{i} = [data.traces{i}; ...
			NaN*ones(nNewFrames, ...
               dataMask.pixelsPerNeuron(i))];
    end

    frame = [];


    for i=1:nNewFrames
      if(mod(i,100) == 0)
        waitbar(i/nNewFrames,waitBar);
      end

      % disp(sprintf('Reading frame %d (total %d)', i, nNewFrames))
      if(isempty(preloadMovie))
        frame = imread(fileName,i);
      else
        frame = preloadMovie(i).data;
      end 

      % If there is more than just grayscale info 
      % then sum channels together
      if(size(frame,3) > 1)
        frame = sum(frame,3);
      end

      % Use second frame if it exists, otherwise first frame
      if(nNewFrames > 1 & i == 2 | nNewFrames == 1)
        lowI = dataMask.imgDispInfo.intensityLow;
        highI = dataMask.imgDispInfo.intensityHigh;

        % Normalise pic to intensity range used before
        frameTmp = min(double(frame), highI);
        frameTmp = max(frameTmp, lowI);
        frameTmp = frameTmp - lowI;
        frameTmp = double(frameTmp)/max(frameTmp(:));

        data.firstFrame(:,:,1) = frameTmp;
        data.firstFrame(:,:,2) = frameTmp;
        data.firstFrame(:,:,3) = frameTmp;

      end

      % Only save the data belonging to the neurons
      for j=1:data.numNeurons
        try
          data.traces{j}(frameOfs+i,:) = ...
              frame(dataMask.pixelList{j});
        catch e
          getReport(e)
          keyboard
        end
      end

    end

    clear preloadMovie

    checkSaturatedPixels();

    waitbar(1,waitBar, 'Calculating average trace...')

    % Calculate the mean traces for the neurons
    data.meanTrace = NaN*ones(data.numFrames,data.numNeurons);

    for i=1:data.numNeurons
      data.meanTrace(:,i) = mean(data.traces{i},2);

      % Loop through all pixels to calculate their distance to 
      % the centroid.
      xCent = dataMask.centroid(i,1);
      yCent = dataMask.centroid(i,2);

      [yPix,xPix] = ind2sub([data.height data.width], dataMask.pixelList{i});
      data.centroidDist{i} = sqrt((xPix-xCent).^2 + (yPix-yCent).^2);

      % Weight by distance, using some exponential?
      %data.meanTraceWeighted = 

      % % Show mean intensity profile
      % data.meanIntensity{i} = mean(data.traces{i},1);
      % 
      % iPixel = find(data.meanIntensity{i} >= 0.8*max(data.meanIntensity{i}));
      % 
      % data.meanTraceHigh(:,i) = mean(data.traces{i}(:,iPixel),2);
      % %!!!! Kolla om denna ar battre an mean.

    end

    %% Calculate the base line, then find artifacts, and recalculate base line
    calculateBaseline();
    detectArtifacts();
    calculateBaseline();

    delete(waitBar);    

    % Make button green to indicate it can be pressed
    set(handles.detect, 'BackgroundColor', [0 0.7 0])


    % Force rescaling of axis
    oldTrace = 0;

    plotTrace();
    showSlice();
    plotEventInspect();
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function saveTraces(source, eventData)

    if(isempty(data.eventStartIdx))
      disp('You must load both mask and trace, and detect events before you can save')
      return
    end

    % Recalculate, just to be on the safe side
    for i=1:data.numNeurons
      calculateEventProperties(i);        
    end

    saveFileSuggestion = strrep(data.traceFile{1},'.tif','-trace.mat');
    saveFileSuggestion = strrep(saveFileSuggestion,'.tiff','-trace.mat');
    saveFileSuggestion = strrep(saveFileSuggestion,'.TIF','-trace.mat');

    % Just some additional information that we also store
    saveData.traceFile          = data.traceFile;
    saveData.height             = data.height;
    saveData.width              = data.width;

    saveData.maskFile           = dataMask.file;
    saveData.neuronMask         = dataMask.neuronMask;
    saveData.neuronMaskNumbered = dataMask.neuronMaskNumbered;
    saveData.pixelList          = dataMask.pixelList;
    saveData.numNeurons         = dataMask.numNeurons;
    saveData.pixelsPerNeuron    = dataMask.pixelsPerNeuron;

    try
      if(~isempty(dataMask.piaDist))
        saveData.piaDist = dataMask.piaDist;
      else
        saveData.piaDist = NaN*zeros(dataMask.numNeurons,1);
      end
    catch
      disp('No pia data found.')
      saveData.piaDist = NaN*zeros(dataMask.numNeurons,1);
    end

    % The most important information that we save
    saveData.centroid           = dataMask.centroid;
    saveData.meanTrace          = data.meanTrace;
    saveData.traces             = data.traces;
    saveData.relTrace           = data.relTrace;

    saveData.eventStartIdx      = data.eventStartIdx;
    saveData.eventStartSlope    = data.eventStartSlope;
    saveData.eventEndIdx        = data.eventEndIdx;
    saveData.eventPeakIdx       = data.eventPeakIdx;
    saveData.eventPeakValue     = data.eventPeakValue;
    saveData.eventArea          = data.eventArea;
    saveData.eventP             = data.eventP;
    saveData.primaryEventIdx    = data.primaryEventIdx;

    saveData.numFrames          = data.numFrames;   

    saveData.xRes               = dataMask.xRes;
    saveData.yRes               = dataMask.yRes;
    saveData.zRes               = dataMask.zRes;
    saveData.freq               = dataMask.freq;

    % Dont forget this, we might not be interested in all putative neurons
    saveData.includeNeuron = data.includeNeuron;
    saveData.specialNeuron = data.specialNeuron;

    saveData.firstFrame = data.firstFrame;

    uisave('saveData',saveFileSuggestion)

    % If modifying here, check that the import function is updated

    saveDetectionConfig();

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function showSlice()

    if(~isempty(dataMask.neuronMask))
      set(handles.fig,'CurrentAxes',handles.slice)

      tmp = zeros(dataMask.height,dataMask.width,3);

      if(~isempty(data.firstFrame) & dispInfo.showFirstFrame)
        tmp = data.firstFrame;
      end

      if(dispInfo.showMask)
        for nIdx = 1:length(dataMask.pixelList)
          % Set colour depending on if the neuron is included or not
          if(data.includeNeuron(nIdx))
            pColor = [1 0 0.6];
          else
            pColor = [0.3 0.3 0.3];
          end

          if(nIdx == iTrace)
            % Green dot if current neuron is included
            % Red dot if it is not included.
            if(data.includeNeuron(iTrace))
              pColor = [0 0.7 0];
            else
              pColor = [0.7 0 0];
            end
          end

          for pIdx = 1:length(dataMask.pixelList{nIdx})
            [y,x] = ind2sub([dataMask.height dataMask.width], ...
                            dataMask.pixelList{nIdx}(pIdx));
            tmp(y,x,:) = pColor;
          end
        end
      end
 
      imgHandle = imshow(tmp);
 
      if(~isempty(dataMask.neuronMask))
        % Display the centroid coordinates of the selected neuron
        xCent = dataMask.centroid(iTrace,1);
        yCent = dataMask.centroid(iTrace,2);

        text(10, dataMask.height-10, ...
             sprintf('(%.0f,%.0f)',xCent,yCent), ...
             'Color',[1 1 1])

        dispInfo.uncheckedImports = ...
            setdiff(dispInfo.uncheckedImports, iTrace);

        hold on
        plot(dataMask.centroid(dispInfo.uncheckedImports,1), ...
             dataMask.centroid(dispInfo.uncheckedImports,2),'b*')
        hold off
        
      end

      % Make sure correct trace number is showing
      set(handles.traceNum,'String', sprintf('%.0f',iTrace));    

    end

    % We also display the names of the mask and traces
  
    tmpString = [];

    if(~isempty(dataMask))
      tmpString = sprintf('%s\n\n', dataMask.file);
      
      if(~isempty(data.traceFile))
        % tmpString = sprintf('%sTrace(s):\n', tmpString);
        
        for iStr = 1:length(data.traceFile)
          tmpString = sprintf('%s%s\n', tmpString, data.traceFile{iStr});
        end
      end

      set(handles.fileNames,'String',tmpString);
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function MouseButtonDownHandler(source,eventdata)

    % Did the user click within the slice

    tmpXY = get(handles.slice,'CurrentPoint');
    xSlice = round(tmpXY(1,1));
    ySlice = round(tmpXY(1,2));

    % Check if we are inside the slice axis
    tmpAxis = axis();

    if(tmpAxis(1) <= xSlice & xSlice <= tmpAxis(2) ...
       & tmpAxis(3) <= ySlice & ySlice <= tmpAxis(4))

      % Yes clicked on slice, is there a neuron underneath it?
      if(dataMask.neuronMaskNumbered(ySlice, xSlice))
        iTrace = dataMask.neuronMaskNumbered(ySlice, xSlice);

        % Plot the new trace
        plotTrace();
        showSlice();
        plotEventInspect();
      end
    end

    % Did the user instead click in the trace
    tmpXY = get(handles.trace,'CurrentPoint');
    xTrace = round(tmpXY(1,1));
    yTrace = round(tmpXY(1,2));

    set(handles.fig,'CurrentAxes',handles.trace)    
    oldAxis = axis();

    if(oldAxis(1) <= xTrace & xTrace <= oldAxis(2) ...
      & oldAxis(3) <= yTrace & yTrace <= oldAxis(4))
      % We are within the trace plot

      switch(get(handles.fig,'SelectionType'))
        case 'normal'
          % Sweet, user did a normal click. Center around mouse cursor
          % This helps navigation in trace

          % We want to preserve level of zooming
          width = oldAxis(2) - oldAxis(1);
          oldCenter = mean(oldAxis(1:2));

          % Only move in x-direction
          dx = xTrace - oldCenter;

          % Range check so that edges do not move outside plot
          dx = max(dx,1-oldAxis(1));
          dx = min(dx,data.numFrames-oldAxis(2));

          oldAxis(1:2) = oldAxis(1:2) + dx;

          axis(oldAxis);
      end
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % Callback function on the trace
  function addEventCallback(source, eventData) 

    tmpXY = get(handles.trace,'CurrentPoint');
    x = round(tmpXY(1,1));

    % We try and find a better start point
    x = findStartOfEvent(iTrace,x);

    % Guess the location of the peak
    peakIdx = findPeakOfEvent(iTrace,x);

    % From peak, look for endIdx
    endIdx = findEndOfEvent(iTrace,peakIdx,detection.endOfEventThreshold);

    % Unique and sort makes sure there are only one event
    % at each frame at most, and that they are in order.

    if(isempty(intersect(data.eventStartIdx{iTrace},x)))

      [data.eventStartIdx{iTrace},idx] = ...
        sort([data.eventStartIdx{iTrace}; x]);

      % Resort the end of events in same manner as start of events
      tmp = [data.eventEndIdx{iTrace}; endIdx];
      data.eventEndIdx{iTrace} = tmp(idx);    

      tmp = [data.eventP{iTrace}; NaN];
      data.eventP{iTrace} = tmp(idx);

      removeEventOverlaps(iTrace);

      calculateBaseline(iTrace);

      calculateEventProperties(iTrace);

      plotTrace();
      plotEventInspect();
    else
      disp('Event already exists')
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function addEvent2Callback(source, eventData)

    tmpXY = get(handles.trace,'CurrentPoint');
    x1 = round(tmpXY(1,1));

    % Mark the start point
    if(~isempty(data.relTrace))
      hold on
      plot(x1,data.relTrace(x1,iTrace),'r*');
      hold off
    else
      hold on
      plot(x1,data.meanTrace(x1,iTrace),'r*');
      hold off
    end

    % First click start, second click end
    [x2,y2] = ginput(1);
    x2 = round(x2);

    if(1 <= x1 & x1 < x2 & x2 <= data.numFrames ...
       & isempty(intersect(data.eventStartIdx{iTrace},x1)))

      [data.eventStartIdx{iTrace},idx] = ...
        sort([data.eventStartIdx{iTrace}; x1]);

      % Resort the end of events in same manner as start of events
      tmp = [data.eventEndIdx{iTrace}; x2];
      data.eventEndIdx{iTrace} = tmp(idx);    

      tmp = [data.eventP{iTrace}; NaN];
      data.eventP{iTrace} = tmp(idx);

      calculateBaseline(iTrace);

      calculateEventProperties(iTrace);

      plotTrace();
      plotEventInspect();
    else
      disp('Try again: First click start, second click end.')
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function deleteEventCallback(source, eventData) 

    tmpXY = get(handles.trace,'CurrentPoint');
    x = round(tmpXY(1,1));
    y = round(tmpXY(1,2));

    disp(sprintf('Del called %d %d', x,y))

    tmpDistStart = abs(data.eventStartIdx{iTrace}-x);
    tmpDistEnd = abs(data.eventEndIdx{iTrace}-x);

    % Pick the closest start/end point, and delete the event
    [foo, delIdx] = min(tmpDistStart);

    if(min(tmpDistStart) > min(tmpDistEnd))
      delIdx = find(min(tmpDistEnd) == tmpDistEnd,1);
    end

    if(~isempty(delIdx) & min([tmpDistStart; tmpDistEnd]) < 10)
      disp(sprintf('Removing event at %d', delIdx))
      data.eventStartIdx{iTrace}(delIdx) = [];
      data.eventEndIdx{iTrace}(delIdx) = [];
      data.eventP{iTrace}(delIdx) = [];

      calculateBaseline(iTrace);

      calculateEventProperties(iTrace);
    end

    plotTrace();
    plotEventInspect();
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function moveStartCallback(source, eventData)
    tmpXY = get(handles.trace,'CurrentPoint');
    x = round(tmpXY(1,1));
    y = round(tmpXY(1,2));

    tmp = abs(data.eventStartIdx{iTrace}-x);
    [foo, moveIdx] = min(tmp);

    % Ask user for new start point
    [x,y] = ginput(1);
    x = round(x);

    % Start point must be before end point!
    if(1 <= x & x < data.eventEndIdx{iTrace}(moveIdx))

      data.eventStartIdx{iTrace}(moveIdx) = x;
      data.eventP{iTrace}(moveIdx) = NaN;

      % Resort events such that starts are in order.
      [data.eventStartIdx{iTrace},idx] = sort(data.eventStartIdx{iTrace});
      data.eventEndIdx{iTrace} = data.eventEndIdx{iTrace}(idx);    
      data.eventP{iTrace} = data.eventP{iTrace}(idx);

      calculateBaseline(iTrace);

      calculateEventProperties(iTrace);

      plotTrace();
      plotEventInspect();
    else
      disp(sprintf('Invalid frame %d, must be before end point of event', x))
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function splitEventCallback(source, eventData)
    % tmpXY = get(handles.trace,'CurrentPoint');
    % x = round(tmpXY(1,1));
    % y = round(tmpXY(1,2));

    % Ask user for new start point
    [x,y] = ginput(1);
    x = round(x);

    if(1 <= x & x <= data.numFrames)

      % Index of event to be split
      splitIdx = find(data.eventStartIdx{iTrace} < x ...
		      & x <= data.eventEndIdx{iTrace},1);

      if(~isempty(splitIdx))
        % Add a new event after split point
        [data.eventStartIdx{iTrace},idx] = sort([data.eventStartIdx{iTrace}; x]);

        tmp = [data.eventEndIdx{iTrace}; data.eventEndIdx{iTrace}(splitIdx)];
        % Set the old events new endpoint
        tmp(splitIdx) = x-1; 

        % Resort the end of events in same manner as start of events
        data.eventEndIdx{iTrace} = tmp(idx);    

        tmp = [data.eventP{iTrace}; NaN];
        data.eventP{iTrace} = tmp(idx);

        calculateBaseline(iTrace);

        calculateEventProperties(iTrace);

        plotTrace();
        plotEventInspect();

      end
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function moveEndCallback(source, eventData)
    tmpXY = get(handles.trace,'CurrentPoint');
    x = round(tmpXY(1,1));
    y = round(tmpXY(1,2));

    tmp = abs(data.eventEndIdx{iTrace}-x);
    [foo,moveIdx] = min(tmp);

    % Find the next crossing of baseline after the current one
    data.eventEndIdx{iTrace}(moveIdx) = ...
        findEndOfEvent(iTrace,data.eventEndIdx{iTrace}(moveIdx), ...
                       detection.endOfEventThreshold);

    calculateBaseline(iTrace);

    calculateEventProperties(iTrace);

    plotTrace();
    plotEventInspect();

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function addArtifactCallback(source, eventData)

    tmpXY = get(handles.trace,'CurrentPoint');
    x1 = round(tmpXY(1,1));

    % Mark the start point
    if(~isempty(data.relTrace))
      hold on
      plot(x1,data.relTrace(x1,iTrace),'b*');
      hold off
    else
      hold on
      plot(x1,data.meanTrace(x1,iTrace),'b*');
      hold off
    end


    % First click was start, second click end
    [x2,y2] = ginput(1);
    x2 = round(x2);

    if(1 <= x1 & x1 < x2 & x2 <= data.numFrames)
      data.artIdx{iTrace} = unique([data.artIdx{iTrace}; ...
                                    transpose(x1:x2)])

      calculateBaseline(iTrace);

      calculateEventProperties(iTrace);

      plotTrace();
      plotEventInspect();

    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function invertTrace(source, event)

    data.meanTrace = max(data.meanTrace(:))-data.meanTrace;

    calculateBaseline();

    plotTrace();

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function shaveFrames(source, event)

    answers = inputdlg('Frames to remove:');
    if(isempty(answers))
      return;
    end

    badFrames = str2num(answers{1});
    goodFrames = setdiff(1:data.numFrames,badFrames);

    fprintf('Removing frames: %s\n', sprintf('%d ', badFrames))

    for i = 1:length(data.traces)
      data.traces{i} = data.traces{i}(goodFrames,:);
    end

    data.meanTrace = data.meanTrace(goodFrames,:);
    data.numFrames = length(goodFrames);

    % Remap the artifact indexes
    for i = 1:length(data.artIdx)
      for j = 1:length(data.artIdx{i})

        nShift = nnz(badFrames < data.artIdx{i}(j));
        data.artIdx{i}(j) = data.artIdx{i}(j) - nShift;

      end
    end

    % Remap event times
    for i = 1:length(data.eventStartIdx)
      for j = 1:length(data.eventStartIdx{i})
        nShift = nnz(badFrames < data.eventStartIdx{i}(j));
        data.eventStartIdx{i}(j) = data.eventStartIdx{i}(j) - nShift;

        nShift = nnz(badFrames < data.eventEndIdx{i}(j));
        data.eventEndIdx{i}(j) = data.eventEndIdx{i}(j) - nShift;

      end
    end

    data.relTrace = [];

    detectEvents();

    setShowRelativeTrace();

    plotTrace();
    plotEventInspect();

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function addArtifactALLCallback(source, eventData)

    tmpXY = get(handles.trace,'CurrentPoint');
    x1 = round(tmpXY(1,1));

    % Mark the start point
    if(~isempty(data.relTrace))
      hold on
      plot(x1,data.relTrace(x1,iTrace),'b*');
      hold off
    else
      hold on
      plot(x1,data.meanTrace(x1,iTrace),'b*');
      hold off
    end


    % First click was start, second click end
    [x2,y2] = ginput(1);
    x2 = round(x2);

    if(1 <= x1 & x1 < x2 & x2 <= data.numFrames)
      for i=1:data.numNeurons
        data.artIdx{i} = unique([data.artIdx{i}; ...
				 transpose(x1:x2)])

        calculateBaseline(i);

        calculateEventProperties(i);
      end

      plotTrace();
      plotEventInspect();

    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function deleteArtifactCallback(source, eventData)

    tmpXY = get(handles.trace,'CurrentPoint');
    x = round(tmpXY(1,1));
    y = round(tmpXY(1,2));

    tmp = abs(data.artIdx{iTrace}-x);
    [foo,aIdx] = min(tmp);

    % Add surrounding points if they are also artifacts
    while(max(aIdx) < length(tmp) ...
          & ismember(data.artIdx{iTrace}(max(aIdx))+1,data.artIdx{iTrace}))
      aIdx = [aIdx; max(aIdx)+1];
    end

    while(min(aIdx) > 1 ...
          & ismember(data.artIdx{iTrace}(min(aIdx))-1,data.artIdx{iTrace}))
      aIdx = [aIdx; min(aIdx)-1];
    end

    if(~isempty(aIdx) & min(tmp) < 10)

      % Remove artifact.
      data.artIdx{iTrace}(aIdx) = [];

      calculateBaseline(iTrace);

      calculateEventProperties(iTrace);

      plotTrace();
      plotEventInspect();

    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function deleteEvents(source, eventData)
    if(~isempty(data.relTrace))
      data.eventStartIdx{iTrace} = [];
      data.eventEndIdx{iTrace} = [];
      data.eventP{iTrace} = [];

      calculateBaseline(iTrace);

      calculateEventProperties(iTrace);

      plotTrace();
      plotEventInspect();
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function trimEvents(source, event)
    verifyTraceTrimming();
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function plotTrace()

    set(handles.fig,'CurrentAxes',handles.trace)    

    % Save axis in case we want to preserve old axis later
    oldAxis = axis;  

    % If the tiff-stack is loaded data.meanTrace exist, 
    % however if events have been detected, then we also 
    % have data.relTrace, so priority displaying that

    if(~isempty(data.relTrace) & ~dispInfo.onlyShowMeanTrace)
      p = plot(data.relTrace(:,iTrace),'k-');
      % Add the right click menu to the plot line also
      set(p,'UIContextMenu',handles.contextMenu);
      hold on
      % Mark the detected artifacts
      p = plot(data.artIdx{iTrace}, ...
               data.relTrace(data.artIdx{iTrace},iTrace),'b*');
      set(p,'UIContextMenu',handles.contextMenu);

    elseif(~isempty(data.meanTrace))
      p = plot(data.meanTrace(:,iTrace),'b-');
      % Add the right click menu to the plot line also
      set(p,'UIContextMenu',handles.contextMenu);

      hold on

      % Mark the detected artifacts
      p = plot(data.artIdx{iTrace}, ...
               data.meanTrace(data.artIdx{iTrace},iTrace),'b*');
      set(p,'UIContextMenu',handles.contextMenu);

    end



    % Display the start and end of the events

    if(~isempty(data.eventStartIdx) ...
       & ~isempty(data.eventStartIdx{iTrace}))
      if(~dispInfo.onlyShowMeanTrace)

        for tIdx=1:length(data.eventStartIdx{iTrace})
          tmpIdx = data.eventStartIdx{iTrace}(tIdx)...
                   :data.eventEndIdx{iTrace}(tIdx);
          p = plot(tmpIdx,data.relTrace(tmpIdx,iTrace),'r-');
          set(p,'UIContextMenu',handles.contextMenu);

          if(~isnan(data.eventP{iTrace}(tIdx)))
            text(data.eventStartIdx{iTrace}(tIdx),1.05, ...
                 sprintf('10^{%d}',ceil(log10(data.eventP{iTrace}(tIdx)))), ...
                 'fontsize',9,'color',[1 0 0])
          end
        end

        % Mark the primary events
        plot(data.primaryEventIdx{iTrace},1.04,'*','color',[1 0 0.6])

        % Plot the start of the event
        % so that call back works.
        p2 = plot(data.eventStartIdx{iTrace}, 1, 'r.','markersize',20);

        % Add the right click menu to the red dots
        set(p2,'UIContextMenu',handles.contextMenu);

        % Plot the end of the events
        p3 = plot(data.eventEndIdx{iTrace}, 1,'ro');
        set(p3,'UIContextMenu',handles.contextMenuEnd);
        
      else
        % Show events but on raw trace

        plot(data.traceBaseline(:,iTrace),'k--')

        for tIdx=1:length(data.eventStartIdx{iTrace})
          tmpIdx = data.eventStartIdx{iTrace}(tIdx)...
                   :data.eventEndIdx{iTrace}(tIdx);
          plot(tmpIdx,data.meanTrace(tmpIdx,iTrace),'r-');
        end

        % Plot the start of the event
        % so that call back works.
        p2 = plot(data.eventStartIdx{iTrace}, ...
                  data.meanTrace(data.eventStartIdx{iTrace},iTrace), ...
                  'r.','markersize',20);...

        % Add the right click menu to the red dots
        set(p2,'UIContextMenu',handles.contextMenu);

        % Plot the end of the events
        p3 = plot(data.eventEndIdx{iTrace}, ... 
                  data.meanTrace(data.eventEndIdx{iTrace},iTrace), ...
                  'ro');
        set(p3,'UIContextMenu',handles.contextMenuEnd);


      end

    end

    hold off

    if(oldTrace ~= iTrace)
      % First time plotted, do not reset to old axis
      oldTrace = iTrace;
    else
      % Reset axis to old axis, for zoom and pan
      axis(oldAxis)
    end

    set(handles.include,'Value', data.includeNeuron(iTrace));
    set(handles.special,'Value',data.specialNeuron(iTrace));
 
    nEvents = length(data.eventStartIdx{iTrace});

    if(nEvents == 0)
      title(sprintf('Trace %d has no events', iTrace))
    elseif(nEvents == 1)
      title(sprintf('Trace %d has 1 event', iTrace))
    else
      title(sprintf('Trace %d has %d events', ...
                    iTrace, nEvents))
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function zoomToEvent(source, event)

    set(handles.fig,'CurrentAxes',handles.trace)

    idx = find(source == handles.eventZoomId,1);

    a = axis(); 
    a(1) = max(1,data.eventStartIdx{iTrace}(idx)-100);
    a(2) = min(data.numFrames,data.eventEndIdx{iTrace}(idx)+100)
    axis(a);

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function plotEventInspect()
    set(handles.fig,'CurrentAxes',handles.eventInspect)

    if(isempty(data.eventStartIdx{iTrace}))
      cla
    end

    % Clear old context menues if they exist
    try
      if(~isempty(handles.eventZoomId))
        for iH = 1:length(handles.eventZoomId)
          delete(get(handles.eventZoomId(iH),'parent'))
        end
      end
    catch exception
      getReport(exception)
      disp('Go talk to Johannes!')
      keyboard
    end

    handles.eventZoomId = zeros(length(data.eventStartIdx{iTrace}),1);

    for eCtr=1:length(data.eventStartIdx{iTrace})
      eIdx = data.eventStartIdx{iTrace}(eCtr):data.eventEndIdx{iTrace}(eCtr);
      p = plot(eIdx - eIdx(1), data.relTrace(eIdx,iTrace),'k-');
      hold on

      % Add a context menu to the plot to allow zooming
      % Menu for zooming in events

      uim = uicontextmenu();
      uimm = uimenu(uim, ...
		    'Label','Zoom event', ...
		    'Interruptible', 'off', ...
		    'Callback', @zoomToEvent);
      
      handles.eventZoomId(eCtr) = uimm;

      set(p,'UIContextMenu', uim)
	  

    end
    hold off

    axis tight
    box off

    if(~isempty(data.eventStartIdx) & ~isempty(data.eventArea{iTrace}))

      set(handles.fig,'CurrentAxes',handles.areaInspect)
      areaEdges = 0:0.5:ceil(max(data.eventArea{iTrace}));
      nArea = histc(data.eventArea{iTrace}, areaEdges);
      b = bar(areaEdges,nArea,'histc');
      set(b,'FaceColor',[1 1 1]*0.6)
      legend('Event area')
      box off
      axis tight


      set(handles.fig,'CurrentAxes',handles.slopeInspect)
      slopeEdges = linspace(min(data.eventStartSlope{iTrace}), ...
                            max(data.eventStartSlope{iTrace}), 15);
      nSlope = histc(data.eventStartSlope{iTrace},slopeEdges);
      b = bar(slopeEdges,nSlope,'histc');
      set(b,'FaceColor',[1 1 1]*0.6)
      legend('Event slope')
      box off
      axis tight

    else
      set(handles.fig,'CurrentAxes',handles.areaInspect)
      cla
      set(handles.fig,'CurrentAxes',handles.slopeInspect)
      cla
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function detectEventsButton(source, eventData)
    if(~isempty(data.meanTrace))

      set(handles.fig,'CurrentAxes',handles.trace) 
      title(' ')

      detectEvents();

      % Mark the button as red, to avoid accidentally pressing it
      set(handles.detect, 'BackgroundColor', [1 0 0])

      setShowRelativeTrace();

      plotTrace();
      plotEventInspect();
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function redetectEventsButton(source, eventData)
    if(~isempty(data.relTrace))

      set(handles.fig,'CurrentAxes',handles.trace) 
      title(' ')

      % This function only does an additional event detection
      % iteration after the previous one.

      detectEventsIteration(detection.pThreshDetect,2,iTrace);

      setShowRelativeTrace();

      plotTrace();
      plotEventInspect();

    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function redetectEventsHighButton(source, eventData)
    if(~isempty(data.relTrace))
      % This function only does an additional event detection
      % iteration after the previous one.

      set(handles.fig,'CurrentAxes',handles.trace) 
      title(' ')

      % We use the upper 10% percentil


      for iP = 2:length(detection.pThreshDetect)
        if(iP < length(detection.pThreshDetect))
        % if(iP == 2 & iP < length(detection.pThreshDetect))
          useMedian = false;
        else
          % For final iteration we want true baseline
          useMedian = true;
        end

        detectEventsIteration(detection.pThreshDetect(iP),2,iTrace,useMedian);
      end

      setShowRelativeTrace();

      plotTrace();
      plotEventInspect();

    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function detectEvents()

    data.traceBaseline = [];
    data.noEventTrace = [];
    data.relTrace = [];
    data.relTraceStd = [];

    for i=1:length(data.numNeurons)
      data.eventStartIdx{i} = [];
      data.eventEndIdx{i} = [];
    end

    waitBar = waitbar(0,'Detecting events in slice...');

    for iter=1:length(detection.pThreshDetect)

      if(iter == 1)
        detectEventsIteration(detection.pThreshDetect(iter),0);
      else
        % We can only do two sided ttest after we have marked the spikes
        % ie, second or later iteration
        detectEventsIteration(detection.pThreshDetect(iter),1);
      end

      waitbar(iter/length(detection.pThreshDetect),waitBar);
    end

    for i = 1:data.numNeurons
      classifyEvents(i);
    end

    waitbar(1,waitBar);
    delete(waitBar);

    setShowRelativeTrace();

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %%% Detection helper functions
  
  %%% This one is obsolete, faster version below.
  function utdata = runningMedianFilterOLD(indata, width)
    % This function calculates the running median, 
    % It handles NaN values, which medfilt1 doesnt.
 
    utdata = NaN*ones(size(indata));

    for n=1:length(indata)
      start = max(1,n-width);
      stop = min(n+width,length(indata));
      utdata(n) = nanmedian(indata(start:stop));
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % Lets see if we can speed up running median
  function utdata = runningMedianFilter(indata, width)
    utdata = NaN*ones(size(indata));

    for n=1:length(indata)
      start = max(1,n-width);
      stop = min(n+width,length(indata));
      tmp = indata(start:stop);
      tmp = tmp(~isnan(tmp));      
      tmp = sort(tmp);
      nTmp = length(tmp);

      if(mod(nTmp,2))
        utdata(n) = tmp(ceil(nTmp/2));
      elseif(nTmp > 0)
        utdata(n) = (tmp(nTmp/2) + tmp(nTmp/2+1))/2;
      elseif(n > 1)
        % There were no data points to calculate median on
        % use the previous value.
        utdata(n) = utdata(n-1);

        set(handles.fig,'CurrentAxes',handles.trace)    
        title('Warning: Running window too small!')
        drawnow
      else
        % This is the first data point, nothing to do, set it to NaN
        % This might propagate into lots of bad errors elsewere
        utdata(n) = NaN;

        set(handles.fig,'CurrentAxes',handles.trace)    
        title('Warning: Running window too small!')
        drawnow

      end
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function utdata = runningPercentilFilter(indata, width,percentil)
    % This function calculates the running median, 
    % It handles NaN values, which medfilt1 doesnt.
 
    utdata = NaN*ones(size(indata));

    for n=1:length(indata)
      start = max(1,n-width);
      stop = min(n+width,length(indata));

      tmpData = sort(indata(start:stop),'descend');
      tmpData = tmpData(~isnan(tmpData));

      if(~isempty(tmpData))
        utdata(n) = tmpData(ceil(length(tmpData)*percentil));
      elseif(n > 1)
        utdata(n) = utdata(n-1);

        set(handles.fig,'CurrentAxes',handles.trace)    
        title('Warning: Running window too small!')
        drawnow
      else
        utdata(n) = NaN;

        set(handles.fig,'CurrentAxes',handles.trace)    
        title('Warning: Running window too small!')
        drawnow
      end
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function detectArtifacts()
    for iA=1:data.numNeurons
      data.artIdx{iA} = find(data.meanTrace(:,iA) ...
			    > data.traceBaseline(:,iA) ...
			      + 4*data.pixelNoiseStd(iA));

      if(~isempty(data.artIdx{iA}))
        disp(strcat(sprintf('Artifacts found in trace %d:', iA), ...
		    sprintf(' %d', data.artIdx{iA})))
      end
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function calculateBaseline(traceIdx,useMedian)

    if(~exist('useMedian'))
      useMedian = true;
    end

    if(exist('traceIdx'))
      calcTraceIdx = traceIdx;
    else
      calcTraceIdx = 1:length(data.traces);
    end

    if(size(data.traceBaseline,1) ~= data.numFrames)
      data.traceBaseline = [];
      data.noEventTrace = [];
    end

    % disp('Calculating baseline')

    % This calculates the base line as a running median, but excludes
    % points that belong to events

    for iLoop=1:length(calcTraceIdx)
      i = calcTraceIdx(iLoop);

      % Remove the events we have detected before doing the running median
      tmpTrace = data.meanTrace(:,i);

      % We get a problem here if the trace is bleaching faster than the
      % median goes down. That will create a really large event.
      for j=1:length(data.eventStartIdx{i})
        idx = data.eventStartIdx{i}(j):data.eventEndIdx{i}(j);
        tmpTrace(idx) = NaN;
      end

      % Also mark the artifacts with NaN
      tmpTrace(data.artIdx{i}) = NaN;

      if(useMedian)
        % Calculate a modified baseline using running median, width 100
        data.traceBaseline(:,i) = ...
            runningMedianFilter(tmpTrace, detection.medianFilterWidth);
      else
        data.traceBaseline(:,i) = ...
          runningPercentilFilter(tmpTrace,detection.medianFilterWidth,0.1);
      end

      % There can be NaN at the beginning of the trace, remove them
      nanIdx = find(isnan(data.traceBaseline(:,i)));

      if(~isempty(nanIdx))
        if(nnz(diff(nanIdx) > 1))
          disp('We have a serious problem, NaN should only appear in beginning')
          % This should never ever happen
          beep
        elseif(nanIdx(1) == 1 & max(nanIdx)+1 < data.numFrames)
          % We have consequtive NaN in beginning
          data.traceBaseline(nanIdx,i) = data.traceBaseline(max(nanIdx)+1,i);
        else
          disp('Unable to recover from NaN')
          beep
          % This should never happen either
        end 
      end

      % We are interested in the fluctuations around the baseline
      % if beyond a certain threshold, this is a candidate event.
      data.pixelNoiseStd(i) = nanstd(tmpTrace - data.traceBaseline(:,i));

      % Save the temp trace, useful for significance test later
      % It has the data points belonging to events removed from the trace
      data.noEventTrace(:,i) = tmpTrace;
    end

    % Calculate deltaF/F
    data.relTrace = data.meanTrace./data.traceBaseline;
    data.relTraceStd = nanstd(data.relTrace - 1);
    data.relNoEventTrace = data.noEventTrace./data.traceBaseline;

    tmpDetect = find(isnan(sum(data.relTrace,1)));
    if(~isempty(tmpDetect))
      disp(sprintf('Trace %d: Found a NaN in dF/F.\n',find(tmpDetect)))
      disp('Try with a different width on the median filter.')
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %% Functions used for decay fitting

  function y = expFitTau(tau,t,amp,expBaseLine)
    y = amp*exp(-t/tau) + expBaseLine;
  end

  function e = expFitTauError(tau,t,yExp,amp,expBaseLine)
    e = norm(expFitTau(tau,t,amp,expBaseLine)-yExp);
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % This function will be called several times.
  % If useMedianFlag is set it will do a look back to find the last crossing of baseline
  % if it was not used, then there is no lookback, since the current baseline is
  % artificially wrong (the 10% percentil), in order to be able to detect very
  % active traces.

  function detectEventsIteration(pThresh, twoSided, traceIdx, useMedianFlag)

    if(~exist('traceIdx'))
      traceIdx = 1:length(data.traces);
    end

    if(~exist('useMedianFlag'))
      useMedianFlag = true;
    end

    disp('Detecting events')
    frameIdx = 1:size(data.relTrace,1);
 
    % Calculate base line and relTrace
    calculateBaseline(traceIdx,useMedianFlag);

    %% Find artifacts and recalculate baseline
    %detectArtifacts();
    %calculateBaseline();


    % To prevent multiple warnings of same type for each trace
    lastWarnTrace = -1;


    for iLoop=1:length(traceIdx) 

      % Modified the code so that we can specify specific traces to iterate
      i = traceIdx(iLoop);

      % We require a certain drop in intensity, compare with previous frame
      okFrames = setdiff(1:data.numFrames, data.artIdx{i});
      minIntensityDrop = min(diff(data.relTrace(okFrames,i)));
      intensityDrop = diff([NaN; data.relTrace(:,i)]);
      intensityDrop(intensityDrop > 0) = 0;
      intensityDrop = intensityDrop / minIntensityDrop;

      % Mark those that are artifacts so that they are not detected as events
      intensityDrop(data.artIdx{i}) = NaN;

      % Find candidate events (below 2 std, UPDATE: now 1 std)
      detection.threshold(i) = ...
          1 - detection.nStdThresh*data.relTraceStd(i);

      candidateEvents = find(data.relTrace(:,i) ...
                             < detection.threshold(i) ...
                             & intensityDrop ...
                             > detection.reqIntensityDrop);

      lastEventEnd = -inf;

      startFrame = NaN*ones(length(candidateEvents),1);
      endFrame   = NaN*ones(length(candidateEvents),1);
      candidateEventsP = NaN*ones(length(candidateEvents),1);

      for j=1:length(candidateEvents)

        % Did previous event end before this data point        
        if(lastEventEnd < candidateEvents(j))

          % Calculate indexes of the subsequent points after the event
          % This includes a range check, so that we do not read outside of matrix
          idx = candidateEvents(j)+1:min(candidateEvents(j)+detection.nDotsCheck, ...
                                         size(data.relTrace,1));

          if(length(idx) < detection.nDotsCheck)
            disp(sprintf('Trace: %d, candidate event at end of trace', i))
          end

          % Do significance test for events, 1 or 2 sided
          if(twoSided)
            [h,p]=ttest2(data.relTrace(idx,i),data.relNoEventTrace(:,i));
          else
            [h,p]=ttest(data.relTrace(idx,i)-1);
          end

          candidateEventsP(j) = p;

          if(candidateEventsP(j) < pThresh)
            tmpIdx = candidateEvents(j);

            % Search backward in trace until curve reaches detection
            % threshold.
            while(tmpIdx > 1 & data.relTrace(tmpIdx,i) < detection.threshold(i))
              tmpIdx = tmpIdx - 1;
            end

            % Now keep searching backwards in trace, until either
            % baseline = 1 is reached or curve starts decreasing again
            % (it checks point before, and two points before)
            % !!! UPDATE: We only do the looking backward if the correct baseline
            % was used (ie the median, this is due to the greedy nature of 
            % how events are excluded from the baseline)

            while(useMedianFlag & tmpIdx > 2 ...
                  & data.relTrace(tmpIdx,i) < 1 ...
                  & data.relTrace(tmpIdx-1,i) < 1 ...
                  & (data.relTrace(tmpIdx,i) < data.relTrace(tmpIdx-1,i) ...
                     | data.relTrace(tmpIdx,i) < data.relTrace(tmpIdx-2,i)))
              tmpIdx = tmpIdx - 1;
            end

            startFrame(j) = tmpIdx;
            peakIdx = findPeakOfEvent(i,startFrame(j));

            endFrame(j) = findEndOfEvent(i,peakIdx, ...
					 detection.endOfEventThreshold, ...
					 true); % Ignore events after

            lastEventEnd = endFrame(j);
          end
        end

      end

      % Only save the valid events.
      data.eventStartIdx{i}   = startFrame(~isnan(startFrame));
      data.eventEndIdx{i}     = endFrame(~isnan(startFrame));
      data.eventP{i}          = candidateEventsP(~isnan(startFrame));

      % Update baseline with correction for new events
      calculateBaseline(i);

      % Calculate event properties
      calculateEventProperties(i);        

    end
    
    if(saveDetectionStats)
      nextIdx = numel(detectionStats) + 1;
      
      detectionStats(nextIdx).events = data.eventStartIdx;
      detectionStats(nextIdx).eventP = data.eventP;
      detectionStats(nextIdx).pThresh = pThresh;
      detectionStats(nextIdx).traceFile = data.traceFile;
      
      fNameStat = sprintf('detectionState-%s.mat', data.traceFile{1});
      save(fNameStat,'detectionStats')
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function startIdx = findStartOfEvent(traceIdx, startIdxGuess)

    if(data.relTrace(startIdxGuess,traceIdx) > 1)
      % We are above baseline, look forward
      startIdx = find(data.relTrace(startIdxGuess:end-1,traceIdx) >= 1 ...
		      & data.relTrace(startIdxGuess+1:end,traceIdx) < 1, ...
		      1,'first') + startIdxGuess - 1;
    else
      % We are below baseline, look backward
      startIdx = find(data.relTrace(1:startIdxGuess-1,traceIdx) >= 1 ...
		      & data.relTrace(2:startIdxGuess,traceIdx) < 1, ...
		      1,'last') + 1;

    end

    prevEndI = find(data.eventEndIdx{traceIdx} < startIdxGuess,1,'last');
    prevEnd = data.eventEndIdx{traceIdx}(prevEndI);

    if(~isempty(startIdx) & ~isempty(prevEnd) & startIdx <= prevEnd)
      disp('Encountered end of previous event, assuming double event')
      tmp = data.relTrace(prevEnd:startIdxGuess);
      startIdx = find(tmp == max(tmp),1)+prevEnd-1;
    end

    if(isempty(startIdx) | abs(startIdx-startIdxGuess) > 50)
      disp('Unable to find a proper crossing within +/- 50 frames')
      startIdx = startIdxGuess;
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function peakIdx = findPeakOfEvent(traceIdx,startIdx)

    endIdx = findEndOfEvent(traceIdx,startIdx,0);

    checkIdx = startIdx:endIdx;
    eventVal = data.relTrace(checkIdx,traceIdx);

    peakIdx = checkIdx(find(eventVal == min(eventVal),1));

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function endIdx = findEndOfEvent(traceIdx, peakIdx, ...
                                   endOfEventThreshold, ignoreEventsAfter)

    if(~exist('ignoreEventsAfter'))
      ignoreEventsAfter = false;
    end

    % We redefine peakIdx as the point after the peak, to avoid ultra short
    % events appearing.
    peakIdx = min(peakIdx+1,size(data.relTrace,1));

    % Find the end of the event
    % Defined as crossing 2*std line from below
    %endIdx = find(data.relTrace(startIdx+1+2:end,traceIdx) ...
    %		  >= detection.threshold(traceIdx) ...
    %		  & data.relTrace(startIdx+1+1:end-1,traceIdx) ...
    %		  < detection.threshold(traceIdx), ...
    %		  1,'first') ...
    %        + startIdx+2;

    if(endOfEventThreshold)
      endIdx = find(data.relTrace(peakIdx:end,traceIdx) ...
                    > 1 - (1-data.relTrace(peakIdx,traceIdx))*endOfEventThreshold,1,'first') ...
               + peakIdx - 1;
    else
      endIdx = find(data.relTrace(peakIdx+1+2:end,traceIdx) >= 1 ...
                    & data.relTrace(peakIdx+1+1:end-1,traceIdx) < 1, 1,'first') ...
      	       + peakIdx+2;
    end

    if(isempty(endIdx))
      endIdx = size(data.relTrace,1);
    end

    if(~ignoreEventsAfter)
      % Are there any new events before this end point??
      sIdx = data.eventStartIdx{traceIdx};
      sIdx = sIdx(find(ismember(sIdx,peakIdx+1:endIdx),1,'first'));
      if(~isempty(sIdx))
        endIdx = max(1,sIdx-1);
      end
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function verifyTraceTrimming()
    % Do this before saving! 

    if(isempty(data.relTrace))
      % Nothing to do, return
      return
    end

    startIdx = findTrimStart(iTrace);
    endIdx = findTrimEnd(iTrace);

    % Since we find start and end idx independently
    % we have to deal with when the accidentally cross
    overlapIdx = find(startIdx(2:end) < endIdx(1:end-1)>0);
    endIdx(overlapIdx) = data.eventStartIdx{iTrace}(overlapIdx+1)-1;
    startIdx(overlapIdx+1) = data.eventStartIdx{iTrace}(overlapIdx+1);

    badStartIdx = setdiff(data.eventStartIdx{iTrace},startIdx);
    altStartIdx = setdiff(startIdx,data.eventStartIdx{iTrace});

    badEndIdx = setdiff(data.eventEndIdx{iTrace},endIdx);
    altEndIdx = setdiff(endIdx,data.eventEndIdx{iTrace});

    if(nnz(data.eventStartIdx{iTrace}-startIdx) ...
       | nnz(data.eventEndIdx{iTrace}-endIdx))
      plotTrace();
      oldAxis = axis;

      hold on
      plot(badStartIdx,data.relTrace(badStartIdx,iTrace),'bo','markersize',10);
      plot(altStartIdx,data.relTrace(altStartIdx,iTrace),'b.','markersize',30);
      plot(badEndIdx,data.relTrace(badEndIdx,iTrace),'go','markersize',10);
      plot(altEndIdx,data.relTrace(altEndIdx,iTrace),'g.','markersize',30);
      hold off
      axis(oldAxis);

      a = questdlg('Trim event starts and ends?','Trimming','Yes','No','No');
      if(strcmp(a,'Yes'))
        % Trim starts 
        data.eventStartIdx{iTrace} = startIdx;
        data.eventEndIdx{iTrace} = endIdx;

        for iA = 1:length(altStartIdx)
          data.eventP{iTrace}(find(altStartIdx(iA) == startIdx,1)) = NaN;
        end

        % Update baseline with correction for new events
        calculateBaseline(iTrace);

        % Calculate event properties
        calculateEventProperties(iTrace);        

        plotTrace();
        plotEventInspect();
      end

    else
      msgbox('Nothing to trim, all okay!','Trim','modal')
      %disp('Nothing to trim, all okay.')
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function startIdx = findTrimStart(traceIdx)
    startIdx = data.eventStartIdx{traceIdx};

    for iS = 1:length(data.eventStartIdx{traceIdx})
      startIdx(iS) = findStartOfEvent(traceIdx,startIdx(iS));
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function endIdx = findTrimEnd(traceIdx)
    % peakIdx = data.eventPeakIdx{traceIdx}; % These were NaNs....
    endIdx = NaN*data.eventEndIdx{traceIdx};

    for iE = 1:length(data.eventEndIdx{traceIdx})
      if(isnan(data.eventPeakIdx{traceIdx}(iE)))
        disp('Guessing peak')
        peakIdx = findPeakOfEvent(traceIdx,data.eventStartIdx{traceIdx}(iE));
      else
        disp('Using old peak')
        peakIdx = data.eventPeakIdx{traceIdx}(iE);
      end

      endIdx(iE) = findEndOfEvent(traceIdx,peakIdx, ...
                                  detection.endOfEventThreshold);
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function removeEventOverlaps(traceIdx)

    for iE = 1:(length(data.eventStartIdx{traceIdx})-1)
      if(data.eventEndIdx{traceIdx}(iE) ...
         >= data.eventStartIdx{traceIdx}(iE+1))
        % Overlapping events...
        fprintf('Found overlapping events at %d (trunkating event)\n', ...
                data.eventStartIdx{traceIdx}(iE+1))
        
        data.eventEndIdx{traceIdx}(iE) = ...
          data.eventStartIdx{traceIdx}(iE+1)-1;

      end
    end

    % Calculate event properties
    calculateEventProperties(traceIdx);        

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function calculateEventProperties(traceIdx)          
  
    data.eventPeakValue{traceIdx} = ...
      NaN*ones(size(data.eventStartIdx{traceIdx}));
    data.eventPeakIdx{traceIdx} = ...
      NaN*ones(size(data.eventStartIdx{traceIdx}));
    data.eventArea{traceIdx} = ...
      NaN*ones(size(data.eventStartIdx{traceIdx}));
    data.eventStartSlope{traceIdx} = ...
      NaN*ones(size(data.eventStartIdx{traceIdx}));    

    delEventIdx = [];

    for iEvent = 1:length(data.eventStartIdx{traceIdx})
      eventFrames = data.eventStartIdx{traceIdx}(iEvent)...
                      :data.eventEndIdx{traceIdx}(iEvent);

      if(isempty(eventFrames))
        disp(sprintf('ERROR: eventFrames for event #%d is empty, removing', iEvent))
        delEventIdx(end+1) = iEvent;
        continue
        %save crashinfo
        %disp('Talk to Johannes!')
        %keyboard
      end

    try
      % Finding minimal value between start and end points
      data.eventPeakValue{traceIdx}(iEvent) = ...
        min(data.relTrace(eventFrames,i));

      % Find where the maxima is
      data.eventPeakIdx{traceIdx}(iEvent) = ...
          find(data.relTrace(eventFrames,i) ...
               == data.eventPeakValue{traceIdx}(iEvent),1) ...
          + data.eventStartIdx{traceIdx}(iEvent) - 1;

      % Find the slope
      eIdx = [data.eventStartIdx{traceIdx}(iEvent) 
              min(data.eventStartIdx{traceIdx}(iEvent)+detection.slopeDt,data.numFrames)];

      data.eventStartSlope{traceIdx}(iEvent) = ...
          diff(data.relTrace(eIdx,traceIdx))/diff(eIdx);


      % Calculate surface area between start and end points
      data.eventArea{traceIdx}(iEvent) = ...
          sum(1 - data.relTrace(eventFrames,i));

    catch exception
      disp('Talk to Johannes!!')
      disp(getReport(exception))
      beep
      save crashinfo
      keyboard
    end

      % !!! Add calculation of start slope

    end

    % Because we are using a for-loop we do not want to delete the items
    % until after we are done. Otherwise we would accidentally skip items.

    if(~isempty(delEventIdx))
      data.eventStartIdx{traceIdx}(delEventIdx) = [];
      data.eventEndIdx{traceIdx}(delEventIdx) = [];
      data.eventP{traceIdx}(delEventIdx) = [];

      data.eventPeakValue{traceIdx}(delEventIdx) = [];
      data.eventPeakIdx{traceIdx}(delEventIdx) = [];
      data.eventArea{traceIdx}(delEventIdx) = [];
      data.eventStartSlope{traceIdx}(delEventIdx) = [];
    end

    % Separate primary and secondary spikes
    classifyEvents(traceIdx);

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function changeEventDetectionSettings(source, eventData)


    prompt = { 'Event threshold (in units of std)', ...
	       'Number of frames to check for significance', ...
               'Required intensity drop (in unit of largest drop)', ...
               'Width of median filter', ...
               'Detection thresholds '};

    defaultVal = { num2str(detection.nStdThresh), ...
                   num2str(detection.nDotsCheck), ...
                   num2str(detection.reqIntensityDrop), ...
                   num2str(detection.medianFilterWidth), ...
                   sprintf('[ %s]', sprintf('%.0d ', detection.pThreshDetect)) };
		   
    dialogName = 'Event detection parameters (saved between sessions)';

    numLines = 1;

    answers = inputdlg(prompt, dialogName, numLines, defaultVal);

    if(~isempty(answers))

      [detection.nStdThresh, modFlag1] = ...
          sanitiseInput(answers{1}, detection.nStdThresh, ...
                        1, 3, false);
      [detection.nDotsCheck, modFlag2] = ...
          sanitiseInput(answers{2}, detection.nDotsCheck, ...
                        2, 10, true);
      [detection.reqIntensityDrop, modFlag3] = ...
          sanitiseInput(answers{3}, detection.reqIntensityDrop, ...
                        0, 1, false);
      
      [detection.medianFilterWidth, modFlag4] = ...
          sanitiseInput(answers{4}, detection.medianFilterWidth, ...
                        100, 500, true);
      
      try
        tmpAns = eval(answers{5});

        if(isa(tmpAns,'double') ...
           & length(tmpAns) >= 2 ...
           & prod(double(tmpAns > 0)) ...
           & prod(double(diff(tmpAns) < 0)))
          detection.pThreshDetect = tmpAns;
          
          modFlag5 = 0;
        else  
          modFlag5 = 1;
        end

      catch exception
        getReport(exception)
        fprintf('Failed to parse threshold: %s\n',answers{5})
        modFlag5 = 1;
      end

      if(modFlag1 | modFlag2 | modFlag3 | modFlag4 | modFlag5)

        warnMsg = sprintf(['The trace is smoothed with a running median ' ...
                           'filter of width %d. If the trace goes %d*std ' ...
                           'below baseline we have a candidate event.' ...
                           'This data point has to have a decrease in ' ...
                           'intensity at least %.2f of largest drop in trace. ' ...
                           '%d points are checked to see if the event is ' ...
                           'significantly different from the noise. ' ...
                           'The threshold values have to be larger than 0, ' ...
                           'and in descending order (at least 2 values).'], ... 
			  detection.medianFilterWidth, ...
			  detection.nStdThresh, ...
			  detection.reqIntensityDrop, ...
			  detection.nDotsCheck);
		   
        uiwait(warndlg(warnMsg, 'Input sanitation','modal'));

      end

    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % Copied from EvA_extractMorphology.m
  %
  % This function is used to sanitise the input, we require that
  % it is a number between minVal and maxVal, and we can also
  % require it to be an integer if we want.
  function [newVal,modFlag] = sanitiseInput(inputString, oldVal, ...
					    minVal, maxVal, integerFlag)
    
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

  function changePiaMask(source, event)

    if(isempty(dataMask.neuronMask))
      disp('No mask loaded.')
      return
    end

    if(~isempty(data.firstFrame))
      sliceImg = data.firstFrame;
    else
      sliceImg = data.neuronMask;
    end

    [dataMask.piaDist, tmp] = ...
        EvA_piaHelper(sliceImg, dataMask.centroid, dataMask.pixelList, ...
                      dataMask.xRes, dataMask.yRes);

  end

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

      set(handles.fig,'CurrentAxes',handles.slice)
      imshow(logoImg);

    catch
      % We end up here in case something failed above
      disp('Unable to load photo from webserver.')

      cachedPics = dir('pics/logo*jpg');

      % If there are cached pictures, choose one of them at random
      if(~isempty(cachedPics))
        idx = randperm(length(cachedPics));
        logoImg = imread(['pics/' cachedPics(idx(1)).name]);

        set(handles.fig,'CurrentAxes',handles.slice)
        imshow(logoImg);
      end
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % This function generates a figure of the trace for the article
  function makeArticleFigure(traceIdx)

    figure
    plot((1:data.numFrames)/dataMask.freq,data.relTrace(:,traceIdx),'k')
    hold on
    plot([1 data.numFrames]/dataMask.freq,[1 1],'r-')
    plot([1 data.numFrames]/dataMask.freq, ...
         [1 1]*(1-detection.nStdThresh*data.relTraceStd(:,traceIdx)),'r--')
    xlabel('Time (s)','fontsize',24) 
    ylabel('Relative intensity','fontsize',24)
    set(gca,'fontsize',20)
    box off

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % Hotkeys for hot girls? ;)

  function KeyPressHandler(source, event)

    switch(event.Key)
      case 'd'
        deleteEvents();

      case 't'
        trimEvents();

      case {'n','rightarrow'}
        nextTrace();

      case {'p','leftarrow'}
        prevTrace();

      case 'r'
        redetectEventsHighButton();

      case 's'
        splitEventCallback();
        
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function saveDetectionConfig()

    fprintf('Saving config to %s\n', cfgFileName)
    save(cfgFileName,'detection');

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function loadDetectionConfig()

    if(exist(cfgFileName))
      fprintf('Loading old config from %s\n', cfgFileName)
      clear old
      old = load(cfgFileName);

      try
        detection.nStdThresh = old.detection.nStdThresh;
        detection.nDotsCheck = old.detection.nDotsCheck;
        detection.reqIntensityDrop = old.detection.reqIntensityDrop;
        detection.medianFilterWidth = old.detection.medianFilterWidth;
        detection.pThreshDetect = old.detection.pThreshDetect;
        detection.burstThreshold = old.detection.burstThreshold;

      catch exception
        % getReport(exception)
        disp('Unable to load config file completely')
      end
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function classifyEvents(iTrace)

    % The threshold idea did not work very well on the noisy traces
    % primStdThresh = 1;
    %
    % eventIdx = data.eventStartIdx{iTrace};
    % idx = find(data.relTrace(eventIdx,iTrace) > 1 - data.relTraceStd(iTrace));
    % data.primaryEventIdx{iTrace} = eventIdx(idx);

    if(isempty(data.eventStartIdx{iTrace}))
      data.primaryEventIdx{iTrace} = [];
    else
      idx = find([1; (data.eventStartIdx{iTrace}(2:end) ...
                      - data.eventEndIdx{iTrace}(1:end-1) ...
                      >= detection.burstThreshold)]);
      data.primaryEventIdx{iTrace} = data.eventStartIdx{iTrace}(idx);
    end

  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % We used to risk getting duplicate events, and events 0 or 1 frames long

  function lookForDuplicates()

    for traceIdx = 1:data.numNeurons

       keepFlag = ones(length(data.eventStartIdx{traceIdx}),1);

       % Remove duplicate events
       dupStartIdx = find(diff(data.eventStartIdx{traceIdx}) == 0);
       dupEndIdx = find(diff(data.eventEndIdx{traceIdx}) == 0);
       keepFlag(intersect(dupStartIdx,dupEndIdx)) = 0;

       % Find any events which are 0 or 1 frames in length
       shortIdx = find(data.eventEndIdx{traceIdx} ...
                       - data.eventStartIdx{traceIdx} <= 1);

       keepFlag(shortIdx) = 0;
       
       % See if there are any remaining overlapping events after we filter
       % the others ... What to do with them?

       nKill = nnz(keepFlag==0);
       if(nKill > 0)
         fprintf('Trace %d: Removing %d events (keeping %d)\n', ...
                 traceIdx, nKill, nnz(keepFlag))
       end

       keepIdx = find(keepFlag);

       data.eventStartIdx{traceIdx} = data.eventStartIdx{traceIdx}(keepIdx);
       data.eventEndIdx{traceIdx} = data.eventEndIdx{traceIdx}(keepIdx);

       data.eventStartSlope{traceIdx} = data.eventStartSlope{traceIdx}(keepIdx);
       data.eventPeakIdx{traceIdx} = data.eventPeakIdx{traceIdx}(keepIdx);
       data.eventPeakValue{traceIdx} = data.eventPeakValue{traceIdx}(keepIdx);
       data.eventArea{traceIdx} = data.eventArea{traceIdx}(keepIdx);

       classifyEvents(traceIdx);
       calculateEventProperties(traceIdx);

       % Where there any overlapping events?
       startIdx = data.eventStartIdx{traceIdx};
       endIdx = data.eventEndIdx{traceIdx};

       overlapIdx = find(startIdx(2:end) < endIdx(1:end-1));
       nOverlap = numel(overlapIdx);
       
       if(nOverlap)
         fprintf('*** Trace %d: %d overlapping events (frames%s)\n', ...
                 traceIdx, nOverlap, ...
                 sprintf(' %d', data.eventStartIdx{traceIdx}(overlapIdx+1)))
       end

    end


  end


  function checkSaturatedPixels()

   saturationThreshold = 15900;
   satFrameThreshold = 0.05;

   badNeuron = [];
   nBadPixels = [];
   nTotPixels = [];

   fprintf('Checking saturation, using threshold of %d intensity\n', ...
           saturationThreshold)

   for i = 1:length(data.traces)

     nFrames = size(data.traces{i},1);
     nSat = sum(data.traces{i} > saturationThreshold);

     if(max(nSat) > 0)
       fprintf('%d saturated pixels in neuron %d\n', nnz(nSat), i)
     end

     nBad = nnz(nSat/nFrames > satFrameThreshold);
     if(nBad)
       fprintf('%d pixels in neuron %d has more than %.0f%% saturated frames\n', ...
               nBad, i, 100*satFrameThreshold)

       badNeuron(end+1) = i;
       nBadPixels(end+1) = nBad;
       nTotPixels(end+1) = size(data.traces{i},2);
     end
   end


    if(~isempty(badNeuron))
      warnStr = sprintf('%d (%d/%d)', badNeuron(1), ....
			nBadPixels(1), nTotPixels(1));

      for i = 2:length(badNeuron)
        warnStr = sprintf('%s, %d (%d/%d)', warnStr, ...
			  badNeuron(i), nBadPixels(i), nTotPixels(i));
      end

      warnStr = sprintf(['Found neurons with pixels that had more ' ...
                         'than %.0f%% ' ...
                         'of their frames saturated. ' ...
                         'Neuron number (bad pixels/total pixels): %s'], ...
			satFrameThreshold*100, warnStr);

      uiwait(warndlg(warnStr, 'Pixel saturation warning'))
    else
      fprintf(['Checked neuron pixel saturation, found no pixels with ' ...
               '%.0f%% or more saturated frames\n'], satFrameThreshold*100)

    end

  end

end
