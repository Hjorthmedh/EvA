%
% Event Analyser (EvA)
%
% EvA_analyse.m
% Analyse the data
%
% Johannes Hjorth
% Julia Dawitz
% Tim Kroon
% Rhiannon Meredith
%
% For questions or suggestions:
% Johannes Hjorth, hjorth@kth.se
%
%

%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function EvA_analyse()

  close all
  format compact

  version = '2017-09-26';

  % Initialise the data-variable so it is visible 
  % in the entire function
   data = struct('traceFile',{}, 'maskFile', '', ...
		 'dataName', '', 'height', 0, 'width', 0, ...
		 'neuronMask', [], 'numberedNeuronMask', [], ...
		 'numNeurons', 0, 'piaDist', [], ...
		 'numExcluded', 0, 'numSpecial', 0, ...
		 'specialIdx', [], ...
		 'eventStartIdx', {}, 'eventStartSlope', {}, ...
		 'eventPeakIdx', {}, 'eventPeakValue', {}, ...
                 'eventAmplitude', {}, ...
		 'eventEndIdx', {}, 'eventArea', {}, ...
                 'eventP', {}, ...
		 'pixelList', {}, 'pixelsPerNeuron', [],  ...
		 'meanTrace', [], 'relTrace', [], 'centroid', [], ...
		 'numFrames', 0, ...
		 'xRes', 0, 'yRes', 0, 'zRes', 0, 'freq', 0, ...
		 'firstFrame', [], ...
		 'eventFreq', [], ...
		 'crossCorr', [], 'shuffleCrossCorr', [], ...
		 'corrP', [], 'neuronClusters', {}, ...
		 'clusterMask', [], 'clusterMaskColor', [], ...
		 'neuronColor', [], ...
		 'rasterOrder', [], ...
                 'traceSum', [], ...
                 'traceSumThreshold', [], ...
		 'clusterEvents', [], ...
		 'clusterFrequency', [], ...
		 'neuronParticipation', [], ...
		 'meanNeuronParticipation', [], ...
		 'SEMNeuronParticipation', [], ...
		 'pairFreq', [], 'pairFreqShuffle', [], ...
		 'nSilentDist', [], 'nSilentDistRef', [], ...
		 'nSpecialDist', [], 'nSpecialDistRef', [], ...
		 'nClusterDist', [], 'nClusterDistRef', [], 'nClusterDistShuffle', [], ...
     'silentDistAll', [], 'silentDistAllRef', [], ...
     'specialDistAll', [], 'specialDistAllRef', [], ...
     'clusterDistAll', [], 'clusterDistAllRef', [], ...
     'clusterDistAllShuffle', [], ...
		 'meanEventAmpAll', [], 'semEventAmpAll', [], ... % Non-special
		 'meanEventAmpClustered', [], 'semEventAmpClustered', [], ...
		 'meanEventAreaAll', [], 'semEventAreaAll', [], ... %Non-special
		 'meanEventAreaClustered', [], 'semEventAreaClustered', [], ...
		 'meanClusterEventAmplitude', [], ...
		 'semClusterEventAmplitude', [], ...
		 'meta', struct());
  

  networkData = [];

  selectIdx = 0;

  % Default parameters  


  detection.CCedges = transpose(-40:40); % transpose(-40.5:40.5);
  detection.nShuffles = 10; %200; %1000;
  detection.corrPThreshold = 0.01; %0.001;
  detection.minNumEvents = 5; % If set to 1, only empty traces are not clustered
  detection.crossCorrDist = 50; %inf;

  detection.distEdges = transpose(linspace(0,500,11));
  detection.pairDt = 5; % This is in frames, also used to calculate participation

  detection.nStdCluster = 5; % How many std over the mean of the max of cluster shuffle
  detection.participationThreshold = 0.4; % Overlap of areas

  detection.autoDetectKernel = false;
  detection.manualKernelWidth = 5;
  detection.kernelScaling = 1;
  detection.kernel = gaussCurve([1 detection.manualKernelWidth], ...
				detection.CCedges);


  dispInfo.markSilent = true;
  dispInfo.markSpecial = true;
  dispInfo.separateRelativeTraces = true;
  dispInfo.onlyMarkStart = true;

  dispInfo.showClusterSum = true;

  exportInfo.exportXMLfile = 'Export.xml';

  iData = 0;

  % Set up GUI
  handles.fig          = figure('Name', ...
				['Event Analyser (EvA) ' ...
				 '- Visualise Analysis'], ...
				'MenuBar','none', ...
				'ToolBar','figure', ...
				'Position', [50 50 1180 720]);

  handles.plotLocation = [60 40 880 660];  
  handles.plot         = axes('Units','Pixels', ...
			      'Position', handles.plotLocation);
  handles.plotRightAxis = [];

  handles.currentPlotNameMask = [];

  % If selectionType = 'normal' (single click), 'open' (double click)
  % Only update plots on double click, or select all on double click?
  handles.selectData = uicontrol('Style','listbox', ...
				 'String', 'None', ...
				 'ToolTipString', ...
				 'Choose data to analyse', ...
				 'Value', [1], ...
				 'Max', 1, 'Min', 1, ...
				 'Callback', @selectData, ...
				 'Interruptible', 'off', ...
				 'Position',[970 430 180 270]);

  handles.info = uicontrol('Style', 'text', ...
			   'String', 'No data selected.', ...
			   'FontSize', 8, ...
			   'BackgroundColor', get(gcf,'color'), ...
			   'Position', [970 340 180 80]);

  handles.plotType = uicontrol('Style','popupmenu', ...
			       'String', {'Plot type list'}, ...
			       'fontsize', 8, ...
			       'Position', [970 200 180 20], ...
			       'Value', 1, ...
			       'Callback', @selectPlot);

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function makePlotTypeList()

    plotList = {};

    for i = 1:length(plotInfo)
      plotList{i} = plotInfo(i).PlotName;
    end

    set(handles.plotType,'String',plotList);

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function selectIdx = selectPlot(source, event)

    resetPlot();

    plotId = get(handles.plotType,'Value');

    selectIdx = allowMultiFileChoice(plotInfo(plotId).AllowMultipleFiles);

    set(handles.fig,'WindowButtonDownFcn',plotInfo(plotId).MouseHandler);
    handles.currentPlotNameMask = plotInfo(plotId).FigNameMask;

    if(~isempty(plotInfo(plotId).PlotParam))
      plotInfo(plotId).PlotFunction(selectIdx,plotInfo(plotId).PlotParam);


    else
      plotInfo(plotId).PlotFunction(selectIdx);
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  plotInfo = struct('PlotName', [], ...
		    'PlotFunction', [], ...
		    'PlotParam', [], ...
		    'AllowMultipleFiles', 1, ...
		    'MouseHandler', [], ...
		    'FigNameMask', []);
  pPos = 1;
  plotInfo(pPos).PlotName = 'Interaction window';
  plotInfo(pPos).PlotFunction = @fitGaussInteraction;
  plotInfo(pPos).AllowMultipleFiles = true;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-gaussInteraction-%s.pdf';

  pPos = 2;
  plotInfo(pPos).PlotName = 'Relative trace';
  plotInfo(pPos).PlotFunction = @plotRelativeTraces;
  plotInfo(pPos).PlotParam = 1;
  plotInfo(pPos).AllowMultipleFiles = false;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-relativeTraces-%s.pdf';;

  pPos = 3;
  plotInfo(pPos).PlotName = 'Raster plot';
  plotInfo(pPos).PlotFunction = @makeOneRasterPlot;
  plotInfo(pPos).AllowMultipleFiles = false;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-rasterPlot-%s.pdf';

  pPos = 4;
  plotInfo(pPos).PlotName = 'Cluster location';
  plotInfo(pPos).PlotFunction = @showClusterLocation;
  plotInfo(pPos).AllowMultipleFiles = false;
  plotInfo(pPos).MouseHandler = @locationClick;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-clusterLocation-%s.pdf';

  pPos = 5;
  plotInfo(pPos).PlotName = 'Correlation distance hist';
  plotInfo(pPos).PlotFunction = @makeCorrelationDistanceHistogram;
  plotInfo(pPos).AllowMultipleFiles = true;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-corrDistHist-%s.pdf';

  pPos = 6;
  plotInfo(pPos).PlotName = 'Show early neurons';
  plotInfo(pPos).PlotFunction = @locateEarlyNeurons;
  plotInfo(pPos).AllowMultipleFiles = false;
  plotInfo(pPos).MouseHandler = @handleEarlyEventSliceClick;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-earlyNeurons-%s.pdf';

  pPos = 7;
  plotInfo(pPos).PlotName = 'Distance distribution (cluster)';
  plotInfo(pPos).PlotFunction = @showNeighbourDistanceDistribution;
  plotInfo(pPos).PlotParam = 'cluster';
  plotInfo(pPos).AllowMultipleFiles = true;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-neighbour-dist-cluster-%s.pdf';

  pPos = 8;
  plotInfo(pPos).PlotName = 'Distance distribution (silent)';
  plotInfo(pPos).PlotFunction = @showNeighbourDistanceDistribution;
  plotInfo(pPos).PlotParam = 'silent';
  plotInfo(pPos).AllowMultipleFiles = true;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-neighbour-dist-silent-%s.pdf';

  pPos = 9;
  plotInfo(pPos).PlotName = 'Distance distribution (cluster shuffled)';
  plotInfo(pPos).PlotFunction = @showNeighbourDistanceDistribution;
  plotInfo(pPos).PlotParam = 'clustershuffled';
  plotInfo(pPos).AllowMultipleFiles = true;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-neighbour-dist-cluster-shuffled-%s.pdf';

  pPos = 10;
  plotInfo(pPos).PlotName = 'Cross correlation';
  plotInfo(pPos).PlotFunction = @showCrossCorr;
  plotInfo(pPos).AllowMultipleFiles = true;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-crossCorr-%s.pdf';;

  pPos = 11;
  plotInfo(pPos).PlotName = 'Cross correlation vs distance';
  plotInfo(pPos).PlotFunction = @showPairFreq;
  plotInfo(pPos).AllowMultipleFiles = true;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-pairFreq-%s.pdf';

  pPos = 12;
  plotInfo(pPos).PlotName = 'Frequency histogram';
  plotInfo(pPos).PlotFunction = @showFrequencyHistogram;
  plotInfo(pPos).AllowMultipleFiles = true;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-freqHist-%s.pdf';

  pPos = 13;
  plotInfo(pPos).PlotName = 'Pair frequency vs age';
  plotInfo(pPos).PlotFunction = @plotNetworkEvolutionPairFreq;
  plotInfo(pPos).AllowMultipleFiles = true;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-network-evolution-pair-freq-%s.pdf';

  pPos = 14;
  plotInfo(pPos).PlotName = 'Frequency (active) vs age';
  plotInfo(pPos).PlotFunction = @plotNetworkEvolutionEventFreqActive;
  plotInfo(pPos).AllowMultipleFiles = true;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-network-evolution-pair-freq-%s.pdf';

  pPos = 15;
  plotInfo(pPos).PlotName = 'Pia distance vs frequency';
  plotInfo(pPos).PlotFunction = @plotPiaDistFreq;
  plotInfo(pPos).AllowMultipleFiles = true;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-piaDist-vs-freq-%s.pdf';

  pPos = 16;
  plotInfo(pPos).PlotName = 'Amplitude histogram (all)';
  plotInfo(pPos).PlotFunction = @plotAmplitudeHistogram;
  plotInfo(pPos).PlotParam = 0; % No filtering
  plotInfo(pPos).AllowMultipleFiles = true;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-amplitudeHistogram-%s.pdf';

  pPos = 17;
  plotInfo(pPos).PlotName = 'Amplitude histogram (clustered)';
  plotInfo(pPos).PlotFunction = @plotAmplitudeHistogram;
  plotInfo(pPos).PlotParam = 1; % Only clustered
  plotInfo(pPos).AllowMultipleFiles = true;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-amplitudeHistogram-clustered-%s.pdf';

  pPos = 18;
  plotInfo(pPos).PlotName = 'Area histogram (all)';
  plotInfo(pPos).PlotFunction = @plotAreaHistogram;
  plotInfo(pPos).PlotParam = 0; % No filtering
  plotInfo(pPos).AllowMultipleFiles = true;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-areaHistogram-%s.pdf';

  pPos = 19;
  plotInfo(pPos).PlotName = 'Area histogram (clustered)';
  plotInfo(pPos).PlotFunction = @plotAreaHistogram;
  plotInfo(pPos).PlotParam = 1; % Only clustered
  plotInfo(pPos).AllowMultipleFiles = true;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-areaHistogram-clustered-%s.pdf';

  pPos = 20;
  plotInfo(pPos).PlotName = 'ISI histogram (all)';
  plotInfo(pPos).PlotFunction = @plotISIHistogram;
  plotInfo(pPos).PlotParam = 0; % No filtering
  plotInfo(pPos).AllowMultipleFiles = true;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-ISI-Histogram-%s.pdf';

  pPos = 21;
  plotInfo(pPos).PlotName = 'ISI histogram (clustered)';
  plotInfo(pPos).PlotFunction = @plotISIHistogram;
  plotInfo(pPos).PlotParam = 1; % Only clustered
  plotInfo(pPos).AllowMultipleFiles = true;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-ISI-Histogram-clustered-%s.pdf';

  pPos = 22;
  plotInfo(pPos).PlotName = 'Correlation matrix';
  plotInfo(pPos).PlotFunction = @plotCorrMatrix;
  plotInfo(pPos).PlotParam = [];
  plotInfo(pPos).AllowMultipleFiles = false;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-cross-corr-matrix-%s.pdf';

  pPos = 23;
  plotInfo(pPos).PlotName = 'Correlation distribution';
  plotInfo(pPos).PlotFunction = @plotCorrDistribution;
  plotInfo(pPos).PlotParam = [];
  plotInfo(pPos).AllowMultipleFiles = false;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-corr-distrib-%s.pdf';

  pPos = 24;
  plotInfo(pPos).PlotName = 'Spatial clustering (alt)';
  plotInfo(pPos).PlotFunction = @plotSpatialClusteringAlt;
  plotInfo(pPos).PlotParam = [];
  plotInfo(pPos).AllowMultipleFiles = true;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-spatial-clustering-alt-%s.pdf';
  
  pPos = 25;
  plotInfo(pPos).PlotName = 'Distance distribution (special)';
  plotInfo(pPos).PlotFunction = @showNeighbourDistanceDistribution;
  plotInfo(pPos).PlotParam = 'special';
  plotInfo(pPos).AllowMultipleFiles = true;
  plotInfo(pPos).FigNameMask = 'FIGS/EvA-neighbour-dist-special-%s.pdf';
  

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % Add plot info to the list.

  makePlotTypeList();

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  handles.credits = uicontrol('Style', 'text', ...
			      'String', 'Johannes Hjorth, Julia Dawitz, Rhiannon Meredith, 2010', ...
			      'HorizontalAlignment', 'right', ...
			      'Foregroundcolor', 0.7*[1 1 1], ...
			      'Backgroundcolor', get(gcf,'color'), ...
			      'Position', [1000 5 175 15], ...
			      'Fontsize',8);

  set([handles.fig, handles.plot, handles.selectData, ...
       handles.info, handles.plotType, ...
       handles.credits], ...
      'units', 'normalized');

  % Get the normalized position
  handles.plotLocation = get(handles.plot,'position');


  handles.menuFile     = uimenu(handles.fig,'Label','File');

  uimenu(handles.menuFile, 'Label','Load File', ...
	                   'Interruptible', 'off', ...
                           'Callback', @loadEventData);

  uimenu(handles.menuFile, 'Label','Load Directory', ...
	                   'Interruptible', 'off', ...
	                   'Callback', @loadMultipleEventData);

  uimenu(handles.menuFile, 'Label','Export data (XML)', ...
	                   'Interruptible', 'off', ...
                           'Callback', @exportToXML);

  uimenu(handles.menuFile, 'Label','Unload selected trace', ...
	                   'Interruptible', 'off', ...
                           'Callback', @unloadTrace);

  uimenu(handles.menuFile, 'Label', 'Export plot', ...
                     	   'Interruptible', 'off', ...
       	                   'Callback',@exportPlot);


  handles.menuView           = uimenu(handles.fig,'Label','View');
	        
  handles.menuItemSelect = uimenu(handles.menuView, ...
				  'Label', 'Select slices', ...
				  'Interruptible', 'off', ...
				  'Callback', @selectSlices);

  handles.menuItemShowSilent = uimenu(handles.menuView, ...
				      'Label','Mark silent neurons', ...
				      'Checked','on', ...
				      'Interruptible', 'off', ...
				      'Callback', @toggleSilentMarking);

  handles.menuItemShowSpecial = uimenu(handles.menuView, ...
				       'Label','Mark special neurons', ...
				       'Checked','on', ...
				       'Interruptible', 'off', ...
				       'Callback', @toggleSpecialMarking);


  handles.menuItemSeparateRel = uimenu(handles.menuView, ...
				       'Label', 'Separate relative traces', ...
				       'Checked','on', ...
				       'Interruptible', 'off', ...
				       'Callback', @toggleSeparateRel);



  handles.menuItemOnlyStart = uimenu(handles.menuView, ...
				     'Label', 'Only start in rasterplot', ...
				     'Checked','on', ...
				     'Interruptible', 'off', ...
				     'Callback',@toggleOnlyMarkStartRaster);

  handles.menuItemClusterSum = uimenu(handles.menuView, ...
				     'Label', 'Show event kernel sum', ...
				     'Checked','on', ...
				     'Interruptible', 'off', ...
				     'Callback',@toggleShowClusterSum);
  
  handles.menuDebug = uimenu(handles.fig,'Label','Debug');
  handles.menuItemDebug =  uimenu(handles.menuDebug, ...
				      'Label','Keyboard', ...
				      'Interruptible', 'off', ...
				      'Callback', @runDebug);

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
      case 'Exploration.DataCursor';
      case 'Standard.EditPlot';
      % Do nothing, we want to keep these
      otherwise 
      delete(oldChild(i));         % Remove the rest
    end
  end

  currentCluster = [];
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % Callback functions

  function runDebug(source, event)
    disp('Type return to exit debug mode')
    keyboard
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function loadEventData(source, event)

    [dataFile dataPath] = ...
	uigetfile({'*-trace.mat', 'Trace file'; ...
		   '*-clustered.mat', 'Cluster file'; ...
		   '*.mat', 'MAT-file'}, ...
		'Select neuron trace file', ...
		'MultiSelect', 'on');

    if(~iscell(dataFile) & dataFile == 0)
      % User pressed cancel
      return;
    end

    if(~iscell(dataFile))
      loadEventFile(dataPath,dataFile);
    else
      for i=1:length(dataFile)
        loadEventFile(dataPath,dataFile{i});    
      end
    end

    if(~isempty(data))

      updateGUI();
      resetPlot();
      fitGaussInteraction();

      for iC=1:length(data)
        findClusterEvents(iC);
        clusterNeurons(iC);
        calculateNeuronProperties(iC);
        % Colour the neurons according to clusters
        colourClusterNeurons(iC);
      end
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function loadMultipleEventData(source, event)
    dataPath = uigetdir(pwd, 'Select directory to load traces from');

    if(dataPath == 0)
      % User pressed cancel
      return
    end

    if(dataPath(end) ~= '/')
      dataPath(end+1) = '/';
    end

    allFiles = dir([dataPath '*-trace.mat']);
    % allFiles = dir([dataPath '*-clustered.mat']);

    % Loop through directory
    for iF=1:length(allFiles)
      loadEventFile(dataPath,allFiles(iF).name);
    end

    if(isempty(allFiles))
      disp(sprintf('No files found in %s.', dataPath))
    end

    if(~isempty(data))
      updateGUI();
      fitGaussInteraction();

      for iC=1:length(data)
        findClusterEvents(iC);
        clusterNeurons(iC);
        calculateNeuronProperties(iC);
        % Colour the neurons according to clusters
        colourClusterNeurons(iC);
      end

    end

  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function loadEventFile(dataPath, dataFile)

    iD = length(data) + 1;

    try
      tmp = load([dataPath dataFile]);
      traceData = tmp.saveData;
    catch e
      % getReport(e)
      disp(sprintf('Unable to open %s%s', dataPath, dataFile))
      return
    end


    % In case something goes wrong reading, so we can crash
    % in a graceful manner.
    try     

      try
        tmpData.traceFile = traceData.traceFile;
        tmpData.maskFile = traceData.maskFile;
      catch
        disp('The trace and mask file names are not stored.')
        tmpData.traceFile = {};
        tmpData.maskFile = [];
      end

      tmpData.dataName = strrep(dataFile,'-trace.mat','');
      tmpData.height = traceData.height;
      tmpData.width = traceData.width;

      tmpData.neuronMask = zeros(size(traceData.neuronMask));
      tmpData.numberedNeuronMask = zeros(size(traceData.neuronMask));

      % Filter out the neurons we do not want to keep
      idx = find(traceData.includeNeuron);
      tmpData.numNeurons = length(idx);
      tmpData.piaDist = NaN*ones(length(idx),1);

      tmpData.numExcluded = nnz(traceData.includeNeuron == 0);
    
      try
        % We are excluding some neurons
        tmpData.numSpecial = nnz(traceData.specialNeuron(idx));

        % Only non-excluded special neurons are included
        tmpData.specialIdx = find(traceData.specialNeuron(idx));
      catch
        disp('No information about special neurons stored.')
        tmpData.numSpecial = NaN;
        tmpData.specialIdx = [];
      end

      piaWarnFlag = 0;

      for i=1:length(idx)
        tmpData.eventStartIdx{i} = traceData.eventStartIdx{idx(i)};
        tmpData.eventStartSlope{i} = traceData.eventStartSlope{idx(i)};
        tmpData.eventPeakIdx{i} = traceData.eventPeakIdx{idx(i)};   
        tmpData.eventPeakValue{i} = traceData.eventPeakValue{idx(i)};   
        tmpData.eventAmplitude{i} = NaN;
        tmpData.eventEndIdx{i} = traceData.eventEndIdx{idx(i)};
        tmpData.eventArea{i} = traceData.eventArea{idx(i)};
        tmpData.eventP{i} = traceData.eventP{idx(i)};

        tmpData.pixelList{i} = traceData.pixelList{idx(i)};
        tmpData.pixelsPerNeuron(i) = traceData.pixelsPerNeuron(idx(i));
        tmpData.neuronMask(traceData.pixelList{idx(i)}) = 1;
        tmpData.numberedNeuronMask(traceData.pixelList{idx(i)}) = i;

        try
          tmpData.piaDist(i) = traceData.piaDist(idx(i));
        catch
          % Save data file did not contain pia distance
	  if(~piaWarnFlag)
  	    disp('No pia information stored')
            piaWarnFlag = 1;
          end

        end

      end

      tmpData.meanTrace = traceData.meanTrace(:,idx);
      tmpData.relTrace = traceData.relTrace(:,idx);
      tmpData.centroid = traceData.centroid(idx,:);
      tmpData.numFrames = traceData.numFrames;

      tmpData.xRes = traceData.xRes;
      tmpData.yRes = traceData.yRes;
      tmpData.zRes = traceData.zRes;
      tmpData.freq = traceData.freq;

      % In case there is no first frame stored (old data format) then
      % we want to fail gracefully.
      try
        tmpData.firstFrame = traceData.firstFrame;
        disp('Loaded first frame')
      catch
        disp('No data for first frame found')
        tmpData.firstFrame = zeros(traceData.height,traceData.width,3);
      end

      % Values calculated later
      tmpData.eventFreq = [];
      tmpData.crossCorr = [];
      tmpData.shuffleCrossCorr = [];
      tmpData.corrP = [];

      try 
        % If EvA_cluster.m was run, this exists
        tmpData.neuronClusters = traceData.neuronClusters;     
      catch
        tmpData.neuronClusters = {};
      end

      try
        % If EvA_cluster.m was run, this exists
        tmpData.clusterMask = traceData.clusterMask;
      catch
        tmpData.clusterMask = [];
      end
      tmpData.clusterMaskColor = [];  
      tmpData.neuronColor = zeros(tmpData.numNeurons,3);

      try 
        % If EvA_cluster.m was run, this exists
        tmpData.rasterOrder = traceData.rasterOrder;
      catch
        tmpData.rasterOrder = 1:tmpData.numNeurons;
      end
      tmpData.traceSum = [];
      tmpData.traceSumThreshold = [];
      tmpData.clusterEvents = [];
      tmpData.clusterFrequency = [];
      tmpData.neuronParticipation = [];
      tmpData.meanNeuronParticipation = [];
      tmpData.SEMNeuronParticipation = [];
      tmpData.pairFreq = [];
      tmpData.pairFreqShuffle = [];
      tmpData.nSilentDist = [];
      tmpData.nSilentDistRef = [];
      tmpData.nSpecialDist = [];
      tmpData.nSpecialDistRef = [];
      tmpData.nClusterDist = [];
      tmpData.nClusterDistRef = [];
      tmpData.nClusterDistShuffle = [];      

      tmpData.silentDistAll = [];
      tmpData.silentDistAllRef = [];
      tmpData.specialDistAll = [];
      tmpData.specialDistAllRef = [];
      tmpData.clusterDistAll = [];
      tmpData.clusterDistAllRef = [];
      tmpData.clusterDistAllShuffle = [];
      
      % Do sanity checking
      if(nnz(isnan(tmpData.relTrace)))
        badIdx = find(isnan(sum(tmpData.relTrace,1)));
        badNeurons = sprintf('%d ', idx(badIdx));
        warnMsg = sprintf('Warning %s contains NaN in relTrace of neuron(s): %s', ...
			  char(dataFile), badNeurons);
			
        uiwait(warndlg(warnMsg, 'Trace file error', 'modal'));
			
      end

      for iT = 1:length(tmpData.eventStartIdx)
        dupIdx = find(diff(tmpData.eventStartIdx{iT}) == 0);

        numDup = nnz(dupIdx);
         if(numDup)
           fprintf('Trace %d has %d events that are duplicates!\n', ...
                   iT, numDup)
	     
           fprintf('Frame: %s\n', ...
                   sprintf('%d ', tmpData.eventStartIdx{iT}(dupIdx)))
         end

         shortIdx = find(tmpData.eventEndIdx{iT}-tmpData.eventStartIdx{iT}<=1);
    
         numShort = nnz(shortIdx);
         if(numShort)
           fprintf('Trace %d has %d events that are 1 frame or shorter!\n', ...
                   iT, numShort)
           
           fprintf('Frame: %s\n', ...
                   sprintf('%d ', tmpData.eventStartIdx{iT}(shortIdx)))

         end

      end

      tmpData.meanEventAmpAll = NaN;
      tmpData.semEventAmpAll = NaN;
      tmpData.meanEventAmpClustered = NaN;
      tmpData.semEventAmpClustered = NaN;

      tmpData.meanEventAreaAll = NaN;
      tmpData.semEventAreaAll = NaN;
      tmpData.meanEventAreaClustered = NaN;
      tmpData.semEventAreaClustered = NaN;
      tmpData.meanClusterEventAmplitude = NaN;
      tmpData.semClusterEventAmplitude = NaN;

      % Load meta data
      tmpData.meta = readMetaData(dataFile);

      data(iD) = tmpData;
      disp(sprintf('%s loaded.', dataFile))

      calculateNeuronProperties(iD);

      % Colour the neurons according to clusters
      colourClusterNeurons(iD);

    catch exception

      % Something went wrong, since the assignment to data(iD)
      % is at the very end nothing got modified in the data
      % structure, we were just unable to load the file.
      disp(sprintf('Unable to load %s.', dataFile))
      disp(getReport(exception))
    end


  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % Load meta data

  function m = readMetaData(traceFileName)

    m.age = NaN;
    m.condition = [];
    m.genotype = [];
    m.hemisphere = [];
    m.sliceNumber = NaN;
    m.totalSlices = NaN;
    m.weight = NaN;

    found = 0;

    if(~exist('metadata.csv'))
      disp('No metadata.csv')
      disp('Format is:')
      disp('trace file name,age in days (can be negative), condition, genotype,hemisphere,slice number, total #slices, weight')
    end

    % Format is:
    % trace file name,age,condition,genotype

    try
      fid = fopen('metadata.csv');
      
      if(fid ~= -1)
      
        allMetaData = textscan(fid,'%s%d%s%s%s%d%d%d','delimiter',',');
        fclose(fid);

        for i=1:length(allMetaData{1})
          if(strcmp(allMetaData{1}{i},traceFileName))
            
            if(found)
              fprintf('%s occurs several times in metadata.csv\n', traceFileName)
              beep
            end
            
            fprintf('Found meta data for %s\n', traceFileName)
            
            m.age = allMetaData{2}(i);
            m.condition = allMetaData{3}{i};
            m.genotype = allMetaData{4}{i};
            m.hemisphere = allMetaData{5}{i};
            m.sliceNumber = allMetaData{6}(i);
            m.totalSlices = allMetaData{7}(i);
            m.weight = allMetaData{8}(i);
            
            disp(sprintf(['Age: %d, Condition: %s, Genotype: %s ' ...
                          'Hemisphere: %s, Slice: %d/%d, Weight: %d'], ...
                         m.age, m.condition, m.genotype, ...
                         m.hemisphere, m.sliceNumber, m.totalSlices, ...
                         m.weight))
            
            found = 1;
          end
        end
      end
      
      if(fid == -1 | ~found)
        disp(sprintf('No meta data for %s', traceFileName))
        %  uiwait(warndlg(sprintf('No meta data for %s', traceFileName), ...
        %		 'Incomplete metadata.csv','modal'))
      end

    catch exception
      disp('Unable to load metadata.csv')
      disp(getReport(exception))
      % uiwait(errordlg('Unable to load metadata.csv', ...
      %      'Meta data error','modal'))
    end


  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function exportToXML(source,event)

   if(isempty(data))
     disp('No data loaded.')
     return
   end

   [fName,fPath] = uiputfile('*.xml','Export file', ...
			     exportInfo.exportXMLfile);

    exportInfo.exportXMLfile = strcat(fPath,fName);

    if(isempty(exportInfo.exportXMLfile))
      return
    end

    % Header info, to make excel feel comfortable with our data...
    docNode = makeXMLheader();

    %%%%% Collect the data...  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    clear meanFreq stdFreq nActive meanFreqActive stdFreqActive
    clear nInCluster meanFreqCluster stdFreqCluster nWeakInCluster

    nInCluster = ones(length(data),1);

    meanFreqCluster = NaN*ones(length(data),1);
    stdFreqCluster = NaN*ones(length(data),1);

    for i=1:length(data)
      % Special cells not included
      normalIdx = setdiff(1:data(i).numNeurons, ...
			  data(i).specialIdx);
      meanFreq(i) = mean(data(i).eventFreq(normalIdx));
      stdFreq(i) = std(data(i).eventFreq(normalIdx));

      activeIdx = intersect(find(data(i).eventFreq > 0),normalIdx);
      nActive(i) = length(activeIdx);
      meanFreqActive(i) = mean(data(i).eventFreq(activeIdx));
      stdFreqActive(i) = std(data(i).eventFreq(activeIdx));

      neuronIdx = data(i).neuronClusters{1};

      % We exclude special cells here
      neuronIdx = intersect(neuronIdx,normalIdx);

      % For freq we also remove those with activity too low to detect
      naIdx = intersect(neuronIdx,activeIdx);

      nInCluster(i,1) = length(neuronIdx);

      meanFreqCluster(i,1) = mean(data(i).eventFreq(naIdx));
      stdFreqCluster(i,1) = std(data(i).eventFreq(naIdx));

    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    columnName = {'Trace file', ... 
		  'Mask file', ...
		  'Number of cells', ...
		  'Number of excluded,' ...
		  'Number of special', ...
		  'Number of active' };

    columnName{end+1} = 'Number in cluster';

    columnName{end+1} = 'Cluster frequency';

    columnName{end+1} = 'Mean frequency (clustered)';
    columnName{end+1} = 'Std frequency (clustered)';

    columnName{end+1} = 'Mean frequency (non-special)';
    columnName{end+1} = 'Std frequency (non-special)';
    columnName{end+1} = 'Mean frequency (active)';
    columnName{end+1} = 'Std frequency (active)';

    columnName{end+1} = 'Mean participation (clustered)';
    columnName{end+1} = 'SEM participation (clustered)';

    columnName{end+1} = 'Mean event amp (cluster events)'
    columnName{end+1} = 'SEM event amp (cluster events)'

    columnName{end+1} = 'Mean event amp (active)'; % non-special
    columnName{end+1} = 'SEM event amp (active)';
    columnName{end+1} = 'Mean event amp (clustered)';
    columnName{end+1} = 'SEM event amp (clustered)';

    columnName{end+1} = 'Mean event area (active)';
    columnName{end+1} = 'SEM event area (active)';
    columnName{end+1} = 'Mean event area (clustered)';
    columnName{end+1} = 'SEM event area (clustered)';

    columnName{end+1} = 'Age';
    columnName{end+1} = 'Condition';
    columnName{end+1} = 'Genotype';
    columnName{end+1} = 'Hemisphere';
    columnName{end+1} = 'Slice Number';
    columnName{end+1} = 'Slice Total';

    tmpMaskFile = {};
    for i = 1:length(data)
      tmpMaskFile{i} = data(i).maskFile;
    end

    tmpTraceFile = {};
    for i = 1:length(data)
      tmpStr = data(i).traceFile{1};

      for j = 2:length(data(i).traceFile)
	tmpStr = sprintf('%s; %s', tmpStr, data(i).traceFile{j});
      end

      tmpTraceFile{i} = tmpStr;
    end

    columnData = { tmpTraceFile, ...
		   tmpMaskFile, ...
		   cat(1,data(:).numNeurons), ...
		   cat(1,data(:).numExcluded), ...
		   cat(1,data(:).numSpecial), ...
		   nActive};

    columnData{end+1} = nInCluster;

    columnData{end+1} = cat(1,data.clusterFrequency);
    columnData{end+1} = meanFreqCluster;
    columnData{end+1} = stdFreqCluster;

    columnData{end+1} = meanFreq;
    columnData{end+1} = stdFreq;
    columnData{end+1} = meanFreqActive;
    columnData{end+1} = stdFreqActive;

    columnData{end+1} = cat(1,data.meanNeuronParticipation);
    columnData{end+1} = cat(1,data.SEMNeuronParticipation);

    columnData{end+1} = cat(1,data.meanClusterEventAmplitude);
    columnData{end+1} = cat(1,data.semClusterEventAmplitude);

    columnData{end+1} = cat(1,data.meanEventAmpAll);
    columnData{end+1} = cat(1,data.semEventAmpAll);
    columnData{end+1} = cat(1,data.meanEventAmpClustered);
    columnData{end+1} = cat(1,data.semEventAmpClustered);

    columnData{end+1} = cat(1,data.meanEventAreaAll);
    columnData{end+1} = cat(1,data.semEventAreaAll);
    columnData{end+1} = cat(1,data.meanEventAreaClustered);
    columnData{end+1} = cat(1,data.semEventAreaClustered);


    tmpAge = [];
    tmpCondition = {};
    tmpGenotype = {};
    tmpHemisphere = {};
    tmpSliceNumber = [];
    tmpTotalSlices = [];

    for i = 1:length(data)
      tmpAge(i)         = data(i).meta.age;
      tmpCondition{i}   = data(i).meta.condition;
      tmpGenotype{i}    = data(i).meta.genotype;
      tmpHemisphere{i}  = data(i).meta.hemisphere;
      tmpSliceNumber(i) = data(i).meta.sliceNumber;
      tmpTotalSlices(i) = data(i).meta.totalSlices;
    end

    columnData{end+1} = tmpAge;
    columnData{end+1} = tmpCondition;
    columnData{end+1} = tmpGenotype;
    columnData{end+1} = tmpHemisphere;
    columnData{end+1} = tmpSliceNumber;
    columnData{end+1} = tmpTotalSlices;

    makeXMLsheet(docNode,'Summary', ...
		 columnName, columnData);

    %%% Information about what masks and trace files make up the data

    columnName = {};
    columnData = {};

    for i = 1:length(data)
      columnName{i} = data(i).maskFile;

      if(length(data(i).traceFile) > 0)
        columnData{i} = data(i).traceFile;
      else
        columnData{i} = 'Unknown file(s)'
      end

    end

    makeXMLsheet(docNode,'Trace files', ...
		 columnName, columnData);

    % Neuron frequency (normal)

    [columnName,columnData] = exportNeuronDetailsNormal('eventFreq');

    makeXMLsheet(docNode,'Neuron frequency (normal)', ...
		 columnName, columnData);


    % Neuron frequency (clustered)

    [columnName,columnData] = exportNeuronDetailsClustered('eventFreq');

    makeXMLsheet(docNode,'Neuron frequency (clustered)', ...
		 columnName, columnData);


    % Neuron participation

    [columnName,columnData] = exportNeuronDetailsClustered('neuronParticipation');

    makeXMLsheet(docNode,'Neuron participations (clustered)', ...
		 columnName, columnData);


    % Neuron cluster flags (normal)

    columnName = {};
    columnData = {};

    for i = 1:length(data)
      columnName{i} = data(i).dataName;
      if(~isempty(data(i).neuronClusters))
        columnData{i} = data(i).neuronClusters{1};
      else
        columnData{i} = [];
      end
    end

    makeXMLsheet(docNode,'Id of clustered neurons', ...
		 columnName, columnData);



    % Write all to disk

    fprintf('Exporting data to %s\n',exportInfo.exportXMLfile);
    xmlwrite(exportInfo.exportXMLfile,docNode);

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function docNode = makeXMLheader()

    docNode = com.mathworks.xml.XMLUtils.createDocument('Workbook');
    docRootNode = docNode.getDocumentElement();

    docRootNode.setAttribute('xmlns','urn:schemas-microsoft-com:office:spreadsheet');
    docRootNode.setAttribute('xmlns:o','urn:schemas-microsoft-com:office:office');
    docRootNode.setAttribute('xmlns:x','urn:schemas-microsoft-com:office:excel');
    docRootNode.setAttribute('xmlns:ss','urn:schemas-microsoft-com:office:spreadsheet');

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % Helper function to write a sheet of data
  % columnData is a cell array, where each element is either a vector 
  % or a cell array. Data in vectors get written as numbers, and data
  % in cell arrays get written as string to the xml file.

  function makeXMLsheet(docNode, ...
			sheetName, ...
			columnHeader, ...
			columnData)

    docRootNode = docNode.getDocumentElement();

    docSheet = docNode.createElement('Worksheet');
    docRootNode.appendChild(docSheet);
    docSheet.setAttribute('ss:Name',sheetName);

    docTable = docNode.createElement('Table');
    docSheet.appendChild(docTable);

    for i = 1:length(columnHeader)
      docTable.appendChild(docNode.createElement('Column'));
    end

    docHeader = docNode.createElement('Row');
    docTable.appendChild(docHeader);

   try

    for i = 1:length(columnHeader)

      docCell = docNode.createElement('Cell');
      docHeader.appendChild(docCell);

      docData = docNode.createElement('Data');
      docData.setAttribute('ss:Type','String');
      % docData.setAttribute('ss:Type','Number');
      docCell.appendChild(docData);

      docData.appendChild(docNode.createTextNode(columnHeader{i}));

    end

    maxRows = 0;

    for j = 1:length(columnData)
      maxRows = max(maxRows, length(columnData{j}));
    end

    for j = 1:maxRows
      docRow = docNode.createElement('Row');
      docTable.appendChild(docRow);

      for i = 1:length(columnData)
        docCell = docNode.createElement('Cell');
        docRow.appendChild(docCell);

        docData = docNode.createElement('Data');
        docCell.appendChild(docData);

        if(length(columnData{i}) < j)
          % This column has less rows of data than other columns
          disp('Short column, leaving additional rows empty.')

          docData.setAttribute('ss:Type','String');
          docData.appendChild(docNode.createTextNode(''));

          continue
        end

        if(isa(columnData{i},'double'))
          % We have numerical data
          if(columnData{i}(j) < inf)
            docData.setAttribute('ss:Type','Number');
            docData.appendChild(docNode.createTextNode(num2str(columnData{i}(j))));
          elseif(isnan(columnData{i}(j)))
            % Leave empty if NaN
            docData.setAttribute('ss:Type','String');
            docData.appendChild(docNode.createTextNode(''));
          else
	    % Excel 2003 cant handle INF, lets give it a HUGE number!
            docData.setAttribute('ss:Type','Number');
            docData.appendChild(docNode.createTextNode('1e300'));
          end
        else
          % We have string data
          docData.setAttribute('ss:Type','String');
          docData.appendChild(docNode.createTextNode(columnData{i}{j}));
        end
      end
    end

   % Temp debug, 
   catch exception
     getReport(exception)
     disp('If you see this, talk to Johannes, he can save your data!')
     keyboard
   end

  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function [columnName, columnData] = exportNeuronDetailsNormal(varName)

    columnName = {};
    columnData = {};

    for i = 1:length(data)
      normalIdx = setdiff(1:data(i).numNeurons,data(i).specialIdx);
      columnName{i} = data(i).dataName;
      columnData{i} = eval(sprintf('data(i).%s(normalIdx)',varName));
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function [columnName, columnData] = exportNeuronDetailsClustered(varName)

    columnName = {};
    columnData = {};

    for i = 1:length(data)
      if(~isempty(data(i).neuronClusters))
        normalIdx = data(i).neuronClusters{1};
      else
        normalIdx = [];
      end

      columnName{i} = data(i).dataName;
      columnData{i} = eval(sprintf('data(i).%s(normalIdx)',varName));
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function unloadTrace(source, event)
    selectIdx = allowMultiFileChoice(true);
    data(selectIdx) = [];

    % Recalculate...
    makeNetworkEvolutionData();

    updateGUI();
    updatePlotSelections()
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function selectSlices(source, event)

    if(isempty(data))
      disp('No data loaded.')
      return
    end

    prompt = { 'Age', 'Genotype', 'Condition' };
    defaultValue = { '9', 'control', 'ACSF' };
    dialogueName = 'Select filter';

    numLines = 1;

    answers = inputdlg(prompt, dialogueName, numLines, defaultValue);

    if(~isempty(answers))
      try
        ageFilter       = eval(answers{1});
        genotypeFilter  = answers{2};
        conditionFilter = answers{3};

        clear tmpMetaAge tmpMetaGenotype tmpMetaCondition

        for i = 1:length(data)
          try
            tmpMetaAge(i) = data(i).meta.age;
            tmpMetaGenotype{i} = data(i).meta.genotype;
            tmpMetaCondition{i} = data(i).meta.condition;
          catch exception
            % Ignore errors...

          end
        end

	ageIdx = find(ismember(tmpMetaAge, ageFilter));
        genoIdx = cellfind(tmpMetaGenotype, genotypeFilter);
        condIdx = cellfind(tmpMetaCondition, conditionFilter);

        % Change the selected neurons
        selectIdx = intersect(ageIdx, intersect(genoIdx,condIdx));
        updateGUI(selectIdx);

      catch exception
        disp(getReport(exception))
        warnMsg = 'Unable to set all answers correctly, please check them again.';
        uiwait(errordlg(warnMsg, 'User input error','modal'));
        selectSlices();

      end
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function toggleSpecialMarking(source, event)

    dispInfo.markSpecial = ~dispInfo.markSpecial;

    if(dispInfo.markSpecial)
      set(handles.menuItemShowSpecial,'checked','on');
    else
      set(handles.menuItemShowSpecial,'checked','off');
    end
 
    if(strcmp(plotInfo(get(handles.plotType,'Value')).PlotName, ...
	      'Cluster location'))
      selectIdx = allowMultiFileChoice(false);
      showClusterLocation(selectIdx);
    end
  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function toggleSilentMarking(source, event)

    dispInfo.markSilent = ~dispInfo.markSilent;

    if(dispInfo.markSilent)
      set(handles.menuItemShowSilent,'checked','on');
    else
      set(handles.menuItemShowSilent,'checked','off');
    end

    if(strcmp(plotInfo(get(handles.plotType,'Value')).PlotName, ...
	      'Cluster location'))
      selectIdx = allowMultiFileChoice(false);
      showClusterLocation(selectIdx);
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function toggleSeparateRel(source, event)

    dispInfo.separateRelativeTraces = ~dispInfo.separateRelativeTraces;

    if(dispInfo.separateRelativeTraces)
      set(handles.menuItemSeparateRel,'checked','on');
    else
      set(handles.menuItemSeparateRel,'checked','off');
    end

    if(strcmp(plotInfo(get(handles.plotType,'Value')).PlotName, ...
	      'Relative trace'))
      selectIdx = allowMultiFileChoice(false);
      plotRelativeTraces(selectIdx,1);
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function toggleOnlyMarkStartRaster(source, event)

    dispInfo.onlyMarkStart = ~dispInfo.onlyMarkStart;

    if(dispInfo.onlyMarkStart)
      set(handles.menuItemOnlyStart,'checked','on');
    else
      set(handles.menuItemOnlyStart,'checked','off');
    end

    if(strcmp(plotInfo(get(handles.plotType,'Value')).PlotName, ...
	      'Raster plot'))
      selectIdx = allowMultiFileChoice(false);
      resetPlot();
      makeOneRasterPlot(selectIdx);
      
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  function toggleShowClusterSum(source, event)
  
    dispInfo.showClusterSum = ~dispInfo.showClusterSum;
    
    if(dispInfo.showClusterSum)
      set(handles.menuItemClusterSum,'checked','on');
    else
      set(handles.menuItemClusterSum,'checked','off');
    end
    
    if(strcmp(plotInfo(get(handles.plotType,'Value')).PlotName, ...
	      'Raster plot'))
      selectIdx = allowMultiFileChoice(false);
      resetPlot();
      makeOneRasterPlot(selectIdx);

    end
    
  end
    
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %% Callback for the list box

  function selectData(source, event)
    disp('Select data called')
    updatePlotSelections();
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %% Callback function for the radio buttons

  function selectType(source, event)
    updatePlotSelections();
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function resetPlot()
    try
      % !!! After exportPlot the old handles.plot is not valid
      % Clear handles.plot after exportPlot, and check here if variable empty
      delete(handles.plot)
    catch 
      disp('No handle to delete.')
    end

    handles.plot = axes('Units','Normalized', ...
			'Position', handles.plotLocation);

    %handles.plot = axes('Units','Pixels', 'Position', handles.plotLocation);

    if(~isempty(handles.plotRightAxis))
      delete(handles.plotRightAxis);
      handles.plotRightAxis = [];
    end

    % Remove any mouse listeners
    set(handles.fig,'WindowButtonDownFcn', '');
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function exportPlot(source, event)
    
    oldFig = gcf;
    oldHandles = handles.plot;
    f = figure('visible','off');
    selectIdx = makePlot();
   
    if(length(selectIdx) > 1)
      traceFile = 'MULTIPLE-TRACES';
    else
      traceFile = data(selectIdx).dataName;
    end

    handles.plot = oldHandles;
    figure(oldFig);

    fileName = sprintf(handles.currentPlotNameMask, traceFile);
    fprintf('Saving to %s\n', fileName)
    saveas(f, fileName, 'pdf');

    fileNameAI = strrep(fileName,'.pdf','.ai');    
    saveas(f,fileNameAI,'ai')
    
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function selectIdx = makePlot()

    selectIdx = selectPlot();

  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function updatePlotSelections()

    if(isempty(data))
      % No data available, ignore this call.
      return
    end

    % For some reason matlab does not handle overlapping axes very well
    % it does not clear the old removed axes before drawing new.

    resetPlot();

    makePlot();

    displayInfo();
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function selectIdx = allowMultiFileChoice(flag)
    if(flag)
      set(handles.selectData,'Max',1000,'Min',1);
      selectIdx = get(handles.selectData,'Value');
    else
      % We only allow one value selected at a time
      % Remove any previous multi-selection

      selectIdx = get(handles.selectData,'Value');
      if(~isempty(selectIdx))
        selectIdx = selectIdx(1);
        set(handles.selectData,'Value', selectIdx)
      end

      set(handles.selectData,'Max',1,'Min',1);
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % This function detects which neuron got clicked and displays 
  % the corresponding cluster raster
  function locationClick(source, event)
    
    tmpXY = get(handles.plot,'CurrentPoint');
    x = round(tmpXY(1,1));
    y = round(tmpXY(1,2));

    % Check if we are inside the slice axis
    tmpAxis = axis();
    selectIdx = allowMultiFileChoice(false);

    if(tmpAxis(1) <= x & x <= tmpAxis(2) ...
       & tmpAxis(3) <= y & y <= tmpAxis(4) ...
       & data(selectIdx).clusterMask(y,x) ~= 0)

      currentCluster = data(selectIdx).clusterMask(y,x);

      resetPlot();
      sp(1) = subplot(2,1,1);
      makeClusterRasterPlot(selectIdx,currentCluster);

      sp(2) = subplot(2,1,2);
      plotRelativeTraces(selectIdx,0,currentCluster);

      % Make subplots correct size
      set(sp(1),'units','normalized');
      set(sp(2),'units','normalized');
      pos1 = get(sp(1),'position');
      pos2 = get(sp(2),'position');
      set(sp(1),'position',[handles.plotLocation(1), pos1(2), ...
 			    handles.plotLocation(3), pos1(4)]) 
      set(sp(2),'position',[handles.plotLocation(1), pos2(2), ...
 			    handles.plotLocation(3), pos2(4)]) 

      linkaxes(sp,'x')

      handles.plot = sp;

      set(handles.fig,'WindowButtonDownFcn', @markTraceHandler);
    end
  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % Functions to calculate the gauss-kernel for the interaction 
  % time overlap.

  function y = gaussCurve(pars,t)
    y = pars(1)*exp(-(t/pars(2)).^2);

    % % Normalise it so that the contribution from all points add up to 1
    % y = y / sum(y);
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function error = gaussCurveError(pars,t,yRef)
    error = norm(gaussCurve(pars,t)-yRef);
  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % Function to fit the gauss kernel to the selected cross-correlogram(s)

  function fitGaussInteraction(dataIdx)

    if(~exist('dataIdx'))
      dataIdx = 1:length(data);
    end

    freq = data(dataIdx(1)).freq;
    for iFreq = 2:length(dataIdx)
      if(freq ~= data(dataIdx(iFreq)).freq)
        disp('All sampling frequencies are not equal!')
        beep
        return % Abort calculations!
      end
    end

    disp('Fitting gaussian to cross-correlogram')

    % First calculate the average cross correlogram using the dataIdx
    CC = [];
    for iCC = 1:length(dataIdx)
      CC = [CC,  (data(dataIdx(iCC)).crossCorr ...
		  - data(dataIdx(iCC)).shuffleCrossCorr)];
    end

    detection.CCsum = sum(CC,2);

    % We only want to use the central part which is above 0
    % This assumes detection.CCedges are set so that only central
    % peak is visible.
    leftCrossing = find(detection.CCsum > 0,1,'first');
    rightCrossing = find(detection.CCsum > 0,1,'last');
    center = ceil(length(detection.CCedges)/2);

    width = min(abs(center-leftCrossing),(rightCrossing-center));
    fitPart = (center-width):(center+width);

    detection.curvePars = fminsearch(@gaussCurveError, [1000 10], [], ...
				     detection.CCedges(fitPart), ...
				     detection.CCsum(fitPart));

    if(detection.autoDetectKernel)
      detection.kernel = gaussCurve(detection.curvePars,  ...
				    detection.CCedges(fitPart));

      detection.kernelScaling = sum(detection.kernel);
      detection.kernel = detection.kernel / detection.kernelScaling;
    else
      detection.kernelScaling = max(detection.CCsum(fitPart));
    end

    % Show the kernel
    bar(detection.CCedges/data(dataIdx(1)).freq, ...
	detection.CCsum, 'histc');
    hold on
    try
      stairs(detection.CCedges(fitPart)/data(dataIdx(1)).freq, ...
             detection.kernel(fitPart)*detection.kernelScaling, ...
             'k','linewidth',3)
    catch e
      getReport(e)
      keyboard
    end
    axis tight
    xlabel('Time (s)')
    ylabel('Bin count')

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % This function shuffles the ISI around and recreates a new trace
  % which should break the interactions between nearby neurons in the
  % new traces. Good for generating a control trace with same ISI 
  % distribution to take into account the increased correlation at
  % higher firing frequencies just by chance.
  %
  % Please note it works with the frame indexes, not with time directly
  % hence the ceil at the end.

  % maxTime here is in number of frames

  function newTraceIdx = shuffleISI(oldTraceIdx, maxTime)
    if(~isempty(oldTraceIdx))
      % Shuffle ISI
      traceISI = [oldTraceIdx(1); diff(oldTraceIdx)];
      newTraceIdx = cumsum(traceISI(randperm(length(traceISI))));
      
      % Shift spike times (modulo max time)
      newTraceIdx = ceil(mod(newTraceIdx-1+maxTime*rand(1),maxTime));

    else
      newTraceIdx = [];
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function shuffleTraceSum = makeShuffleSum(dataIdx)

    shuffleEventSum = zeros(data(dataIdx).numFrames,1);

    for iE = 1:length(data(dataIdx).eventStartIdx)
      shuffleEventIdx = shuffleISI(data(dataIdx).eventStartIdx{iE}, ...
				   data(dataIdx).numFrames);
      shuffleEventSum(shuffleEventIdx) = shuffleEventSum(shuffleEventIdx) + 1;
    end

    shuffleTraceSum = addKernel(shuffleEventSum);

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function gaussTrace = addKernel(binaryTrace)

    kernelIdx = (1:length(detection.kernel))-1;
    gaussTrace = zeros(length(binaryTrace) + length(detection.kernel),1);
    idxT = find(binaryTrace);

    for iT = 1:length(idxT);
      gaussTrace(idxT(iT)+kernelIdx) = ...
	gaussTrace(idxT(iT)+kernelIdx) + binaryTrace(idxT(iT))*detection.kernel;
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function newTraceIdx = randomTraceShuffle(oldTraceIdx, maxTime)
    nSpikes = length(oldTraceIdx);

    spikeIdx = ceil(rand(nSpikes,1)*maxTime);
    newTraceIdx = unique(spikeIdx);

    while(length(newTraceIdx) < nSpikes)
      newTraceIdx = [newTraceIdx;ceil(rand(1)*maxTime)];
    end

    newTraceIdx = unique(spikeIdx);

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function mutInfoMat = mutualInformationMatrix(dataIdx)

    mutInfoMat = ones(data(dataIdx).numNeurons,data(dataIdx).numNeurons);
    trace = addKernel(dataIdx);

    % Calculate the mutual information
    for iA=1:data(dataIdx).numNeurons
      for iB=iA+1:data(dataIdx).numNeurons
        mutInfoMat(iA,iB) = condMutInfo(trace(:,iA),trace(:,iB));
        mutInfoMat(iB,iA) = mutInfoMat(iA,iB);
      end
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % This function calculates the conditional mutual information for the traces
  % Z = either X or Y is non-zero
  % http://en.wikipedia.org/wiki/Mutual_information

  % A BETTER THING MIGHT BE TO USE ENTROPY FOR THE TRACES ALONE AND
  % JOINTLY TO ESTIMATE MUTUAL INFORMATION.

  function m = condMutInfo(traceA,traceB)
    maxTrace = 3*max(detection.kernel);
    minTrace = 0;
    nBins = 30;
    m = 0;

    if(max(traceA) > maxTrace | max(traceB) > maxTrace)
      disp('WARNING : max is set to low in condMutInfo, increase!')
    end

    edges = linspace(minTrace,maxTrace,nBins);

    % We need to remove the bits when both traces are 0
    idx = find(traceA | traceB);

    PZ = length(idx)/length(traceA);    

    if(PZ > 0)
      % Only do this if there are at least one event
      PABZ = hist3([traceA(idx), traceB(idx)], {edges,edges});
    
      PAZ = repmat(sum(PABZ,2),1,nBins);
      PBZ = repmat(sum(PABZ,1),nBins,1);
 
      tmp = PABZ.*log(PZ.*PABZ./(PAZ.*PBZ));
      % This becomes NaN if PAZ or PBZ is 0, but then PABZ also 0.
      % So set the NaN to 0. Uglu, I know. Sorry about that.
      tmp(isnan(tmp)) = 0;

      m = sum(tmp(:));
    end

    disp('Something is fishy with the mutual information calculation')
    keyboard

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function plotRelativeTraces(dataIdx, useSubplot,clusterIdx,markIdx)

    time = (1:data(dataIdx).numFrames) / data(dataIdx).freq;

    if(useSubplot)

      clustIdx = [];
      for i = 1:length(data(dataIdx).neuronClusters)
	clustIdx = [clustIdx; data(dataIdx).neuronClusters{i}];
      end

      restIdx = setdiff(1:data(dataIdx).numNeurons,clustIdx);

      sp(1) = subplot(2,1,1);
      offset = 0;

      for i = 1:length(clustIdx)
	plot(time, data(dataIdx).relTrace(:,clustIdx(i))+offset, ...
	     'color', data(dataIdx).neuronColor(clustIdx(i),:))
        hold on

        if(dispInfo.separateRelativeTraces)
	  offset = offset + 0.4;
        end
      end

      if(~dispInfo.separateRelativeTraces)
        plot([1 max(time)],[1 1],'k-')
      end  
      hold off

      sp(2) = subplot(2,1,2);
      offset = 0;

      for i = restIdx

        % Add an offset 
	plot(time,data(dataIdx).relTrace(:,i)+offset, ...
	     'color', data(dataIdx).neuronColor(i,:))
        hold on

        if(dispInfo.separateRelativeTraces)
	  offset = offset + 0.4;
        end
      end

      if(~dispInfo.separateRelativeTraces)
        plot([1 max(time)],[1 1],'k-')
      end
      hold off

      linkaxes(sp,'x')
      set(sp(1),'units','normalized');
      set(sp(2),'units','normalized');
      pos1 = get(sp(1),'position');
      pos2 = get(sp(2),'position');
      set(sp(1),'position',[handles.plotLocation(1), pos1(2), ...
 			    handles.plotLocation(3), pos1(4)]) 
      set(sp(2),'position',[handles.plotLocation(1), pos2(2), ...
 			    handles.plotLocation(3), pos2(4)]) 

      handles.plot = sp;

    else
      if(exist('clusterIdx'))
        nIdx = data(dataIdx).neuronClusters{clusterIdx};
        for i = 1:length(nIdx)
	  plot(time, data(dataIdx).relTrace(:,nIdx(i)), ...
	       'color', data(dataIdx).neuronColor(nIdx(i),:))
          hold on
        end 

        if(exist('markIdx'))
 	  for i = 1:length(markIdx)
	    p(i) = plot(time,data(dataIdx).relTrace(:,nIdx(markIdx(i))), ...
		     'color', [0.75 0.5 0.75]);
            pLeg{i} = sprintf('Neuron %d', markIdx(i));    
          end
	  legend(p,pLeg,'location','best')
        end
      else
        for i = 1:data(dataIdx).numNeurons
	  plot(time, data(dataIdx).relTrace(:,i), ...
   	       'color', data(dataIdx).neuronColor(i,:))
          hold on
        end
      end
      plot([1 max(time)],[1 1],'k-')
      hold off
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function markTraceHandler(source,event)

    tmpXY = get(handles.plot(1),'CurrentPoint');
    x = round(tmpXY(1,1));
    y = round(tmpXY(1,2));

    nNeurons = length(data(selectIdx).neuronClusters{currentCluster});

    % fprintf('Mouse pressed at x = %d, y = %d\n', x,y)
    % fprintf('nNeurons = %d, max time = %d\n', ...
    %	      nNeurons, data(selectIdx).numFrames/data(selectIdx).freq)

    if(1 <= y & y <= nNeurons ...
       & 1 <= x & x <= data(selectIdx).numFrames/data(selectIdx).freq)
      % disp('Processing...')
      % User is clicking on a trace, mark it in relative trace

      markIdx = y;

      resetPlot();
      sp(1) = subplot(2,1,1);
      makeClusterRasterPlot(selectIdx,currentCluster,markIdx);

      sp(2) = subplot(2,1,2);
      plotRelativeTraces(selectIdx,0,currentCluster,markIdx);

      % Make subplots correct size
      set(sp(1),'units','normalized');
      set(sp(2),'units','normalized');
      pos1 = get(sp(1),'position');
      pos2 = get(sp(2),'position');
      set(sp(1),'position',[handles.plotLocation(1), pos1(2), ...
 			    handles.plotLocation(3), pos1(4)]) 
      set(sp(2),'position',[handles.plotLocation(1), pos2(2), ...
 			    handles.plotLocation(3), pos2(4)]) 

      linkaxes(sp,'x')
      handles.plot = sp;

      set(handles.fig,'WindowButtonDownFcn', @markTraceHandler);

    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % C! Remove this function altogether, because now we only have one
  %    cluster, and its colour is [0.4 0.52 1]

  function colourClusterNeurons(dataIdx)

    if(isempty(data(dataIdx).clusterMask))
      % No cluster information available
      return
    end

    %data(dataIdx).clusterMaskColor = ...
    %  label2rgb(data(dataIdx).clusterMask);

    uId = setdiff(unique(data(dataIdx).clusterMask),0);
    colorMask = zeros(data(dataIdx).height,data(dataIdx).width,3);

    % Precolour all neurons as grey
    [y,x] = ind2sub(size(data(dataIdx).neuronMask), ...
		    find(data(dataIdx).neuronMask));
    
    for i = 1:length(x)
      colorMask(y(i),x(i),:) = 0.2*[1 1 1];
    end

    colMap = colormap('jet');

    if(~isempty(data(dataIdx).neuronClusters))
      idx = data(dataIdx).neuronClusters{1};
      primFreq = mean(data(dataIdx).eventFreq(idx));
    else
      % No primary cluster
      primFreq = NaN;
    end

    for iD = 1:length(uId)
      [y,x] = ind2sub(size(data(dataIdx).clusterMask), ...
		      find(data(dataIdx).clusterMask == uId(iD)));

      meanFreq = mean(data(dataIdx).eventFreq(data(dataIdx).neuronClusters{uId(iD)}));

      if(0 < meanFreq & 0.1*primFreq < meanFreq)
        % Colour the cluster normally

        for iC = 1:3
	  if(length(uId) == 1)
            tmpCol = [0.5 0.25 0.5];
          else
            tmpCol(iC) = interp1(linspace(1,length(uId),64), ...
				 colMap(:,iC), iD);
          end
        end
      else
        % Too little activity, colour it grey
        tmpCol = 0.3*[1 1 1];
      end


      for iC = 1:length(x)
        colorMask(y(iC),x(iC),:) = tmpCol*255;
      end
    end

    data(dataIdx).clusterMaskColor = colorMask;


    % Store the colour of each neuron

    for iN = 1:data(dataIdx).numNeurons
      pixelId = data(dataIdx).pixelList{iN}(1);

      [y,x] = ind2sub([data(dataIdx).height, ...
		       data(dataIdx).width], ...
		      pixelId);

      tmp = data(dataIdx).clusterMaskColor(y,x,:)/255;
      if(nnz(tmp == 1) == 3)
        tmp = [0 0 0];
      end

      data(dataIdx).neuronColor(iN,:) = tmp;

    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function showClusterLocation(dataIdx)

    if(nnz(data(dataIdx).firstFrame))
      tmpImg = data(dataIdx).firstFrame;
      tmpImg = tmpImg / (3* max(tmpImg(:)));
      tmpImg(:,:,[1 3]) = 0;
    else
      tmpImg = ones(size(data(dataIdx).firstFrame));
    end

    tmp = sum(data(dataIdx).clusterMaskColor,3);

    idx = find(tmp ~= 0);
    [y,x] = ind2sub([data(dataIdx).height data(dataIdx).width],idx);

    for iP = 1:length(idx)
      tmpImg(y(iP),x(iP),:) = ...
	       data(dataIdx).clusterMaskColor(y(iP),x(iP),:)/255;
    end

    imshow(tmpImg);
    %imshow(data(dataIdx).clusterMaskColor); 
    %image(data(dataIdx).clusterMaskColor); 
    hold on

    % Marks special neurons
    if(dispInfo.markSpecial & ~isempty(data(dataIdx).specialIdx))
      specialCoords = data(dataIdx).centroid(data(dataIdx).specialIdx,:);
      plot(specialCoords(:,1),specialCoords(:,2),'w*','markersize',10)
    end

    % Mark silent neurons
    silentIdx = find(data(dataIdx).eventFreq == 0);

    if(dispInfo.markSilent & ~isempty(silentIdx))
      silentCoords = data(dataIdx).centroid(silentIdx,:);

      plot(silentCoords(:,1),silentCoords(:,2),'ko','markersize',10)
      plot(silentCoords(:,1),silentCoords(:,2),'wo','markersize',5)

    end

    xlabel(''), ylabel('')

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function makeCorrelationDistanceHistogram(dataIdx)
    edges = transpose(linspace(0,1,50));
    nAll = zeros(size(edges));
    nAllShuffle = zeros(size(edges));

    for iD = 1:length(dataIdx)
      % The pdist function wants the traces in row format
      traces = transpose(1-data(dataIdx(iD)).relTrace);
      D = pdist(traces,'correlation');
      n = histc(D(:),edges);
      nAll = nAll + n; 

      % Create a shuffled version for comparision purposes
      traceShuffle = zeros(size(traces)); 

      for i = 1:data(dataIdx(iD)).numNeurons
	x = ceil(data(dataIdx(iD)).numFrames*rand(1));
        if(x > 1)
          tracesShuffle(i,:) = [traces(i,x:end), traces(i,1:x-1)];
        end
      end

      Dshuffle = pdist(tracesShuffle,'correlation');
      n = histc(Dshuffle(:),edges);
      nAllShuffle = nAllShuffle + n; 

    end

    p(2) = bar(edges,nAllShuffle,'facecolor',[0 0 0],'edgecolor',[0 0 0],'barwidth',0.8);
    hold on
    p(1) = bar(edges,nAll,'facecolor',[1 0 0],'edgecolor',[1 0 0],'barwidth',0.5);
    xlabel('Correlation distance')
    ylabel('Bin count')
    a = axis; a(1) = 0 - edges(2); a(2) = max(edges)+edges(2); axis(a);
    legend(p,'Data','Shuffled','location','best')

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % !!!! There is a mistake here somewhere in the contains events function

  % This function checks if a PCA component is just noise or if it contains 
  % events.
  function hasEvents = containsEvents(pcaTrace)

    nFrames = length(pcaTrace);
    fitFrames = 50;
    peakDelay = 20; % How many frames after drop the peak will be within
    minPeakDist = 20;
    debugMode = 1;


    % 0. Figure out if we should look for sharp drops or increases?

    % if(median(pcaTrace) > 0)
    %   traceSign = -1;
    % else
    %   traceSign = 1;
    % end

    % 1. Locate frames with sharp changes in the trace.
    dTrace = diff(pcaTrace);

    traceSign = sign(dTrace(find(max(abs(dTrace)) == abs(dTrace),1)));

    % Switch trace so we are looking for maximas
    pcaTrace = pcaTrace*traceSign;
    dTrace = dTrace*traceSign;

    mDt =  mean(dTrace);
    sDt = std(dTrace);

    dropMask = double(dTrace > mDt + 2*sDt);
    idx = find(dropMask);

    peakIdx = [];

    % Look for local maxima in trace after the big drop

    for i = 1:length(idx)
      startIdx = idx(i);
      endIdx = min(idx(i)+peakDelay,nFrames);

      offset = find(pcaTrace(startIdx:endIdx) ...
		     == max(pcaTrace(startIdx:endIdx)), 1) -1;
        
      peakIdx(end+1) = idx(i) + offset;

    end    

    % Keep only unique local maximas
    peakIdx = unique(peakIdx);

    % Remove peaks that are too close together, use 2nd peak then
    peakIdx(find(diff(peakIdx) < minPeakDist)) = [];

    % Remove peaks too close to end
    peakIdx(find(peakIdx >= nFrames - minPeakDist)) = [];

    % Pad the peakIdx vector
    peakIdx(end+1) = nFrames;

    % 2. Fit exponential decays to the putative events

    tau = NaN*zeros(size(peakIdx));
    fitError = NaN*zeros(size(peakIdx));

    for i = 1:(length(peakIdx)-1)
      startIdx = peakIdx(i);
      % Use N frames, however never overlap with following event.
      endIdx = min([peakIdx(i)+fitFrames,peakIdx(i+1)-1,nFrames]);

      try  
        % Fit exponential.
        [tau(i),fitError(i)] = fitExp(pcaTrace(startIdx:endIdx), ...
				      max(pcaTrace),min(pcaTrace));
      catch exception
        disp(getReport(exception))
        save crashinfo
        disp('Oops not good, talk to Johannes.')
        keyboard
      
      end

    end

    % Are any of the events valid?
    eventMask = 15 <= tau & tau <= 30 & fitError < 0.05;
    % This is not fool proof!
    if(nnz(eventMask)) 
      hasEvents = true;
    else
      hasEvents = false;
    end

    tau, fitError

    if(debugMode)
      fig = gcf;
      figure
      plot(1:nFrames,pcaTrace,'k-', ...
	   peakIdx(1:end-1),pcaTrace(peakIdx(1:end-1)),'b*')

      hold on
      plot(peakIdx(eventMask),pcaTrace(peakIdx(eventMask)),'r*')

      for i=1:length(tau)
        text(peakIdx(i),pcaTrace(peakIdx(i)),num2str(tau(i)))
      end

      figure(fig);
    end


  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function [tau,err] = fitExp(trace,maxTrace,minTrace)

    fn = transpose(1:length(trace))-1; % Frame numbers
    
    tau = fminsearch(@(x)norm(trace-((maxTrace-minTrace)*exp(-fn/x) ...
				     +minTrace)),5);

    err = norm(trace-((maxTrace-minTrace)*exp(-fn/tau)+minTrace)) ...
      /length(trace);

    if(0)
      f = gcf;
      figure
      plot(trace,'k'), hold on
      plot(((maxTrace-minTrace)*exp(-fn/tau)+minTrace),'r-')
      title(sprintf('\tau = %d, error = %d', tau,err));

      figure(f);

    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function calculateNeuronProperties(calcIdx)

    % If nothing is specified we calculate all data-sets
    if(~exist('calcIdx'))
      calcIdx = 1:length(data);
    end

    disp('Calculating neuron properties')

    for iCalc = 1:length(calcIdx)
      iData = calcIdx(iCalc);

      for iTrace=1:length(data(iData).eventStartIdx)

	 % Calculate frequency (freq is sampling frequency)
	 data(iData).eventFreq(iTrace,1) =...
	   length(data(iData).eventStartIdx{iTrace}) ...
		   * data(iData).freq / data(iData).numFrames;
      end

      % Calculate the cross-correlogram for neurons at choosen distance
      maxDist = detection.crossCorrDist;
      [data(iData).crossCorr, data(iData).shuffleCrossCorr] = ...
          crossCorrelogramDistanceRange(iData, 0, maxDist);

      % Calculate the pairCount
      countPairFreq(iData,detection.distEdges,detection.pairDt)

      % Calculate distance distribution
      calculateNeighbourDistanceDistribution(iData,detection.distEdges);

      % Make sure we calculate it for all cells
      % calculateAmps(iData,1:data(iData).numNeurons);
      
      % Non-special neurons
      [data(iData).meanEventAmpAll,data(iData).semEventAmpAll] = ...
	calculateAmps(iData, ...
		      setdiff(1:data(iData).numNeurons, ...
			      data(iData).specialIdx));

      [data(iData).meanEventAreaAll,data(iData).semEventAreaAll] = ...
	calculateAreas(iData, ...
		      setdiff(1:data(iData).numNeurons, ...
			      data(iData).specialIdx));


      if(~isempty(data(iData).neuronClusters))
	clusterIdx = data(iData).neuronClusters{1};
      else
	clusterIdx = [];
      end

      [data(iData).meanEventAmpClustered, ...
       data(iData).semEventAmpClustered] = ...
	calculateAmps(iData,clusterIdx);

      [data(iData).meanEventAreaClustered, ...
       data(iData).semEventAreaClustered] = ...
	calculateAreas(iData,clusterIdx);

      calculateNeuronParticipation(iData);

    end

    % Calculate the evolution of network properties over time
    makeNetworkEvolutionData();


  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function [meanAmp,semAmp] = calculateAmps(sliceIdx,cellIdx)

    allAmps = [];

    for i = 1:length(cellIdx)
      % Amplitude is 1 - peak value.
      % allAmps = [allAmps; 1-data(sliceIdx).eventPeakValue{cellIdx(i)}];

        % Redefined to be peak value - value at start of event
	minPeak = data(sliceIdx).eventPeakValue{cellIdx(i)};
        startFrame = data(sliceIdx).eventStartIdx{cellIdx(i)};
        startVal = data(sliceIdx).relTrace(startFrame,cellIdx(i));

        if(~isempty(minPeak))
          data(sliceIdx).eventAmplitude{cellIdx(i)} = startVal - minPeak;
        else
	  data(sliceIdx).eventAmplitude{cellIdx(i)} = [];
        end

        if(~isempty(minPeak))
          allAmps = [allAmps; startVal-minPeak];         
        end

    end

    meanAmp = mean(allAmps);
    semAmp = std(allAmps)/sqrt(length(allAmps));

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function [meanArea,semArea] = calculateAreas(sliceIdx,cellIdx)

    allAreas = [];

    for i = 1:length(cellIdx)
      allAreas = [allAreas; data(sliceIdx).eventArea{cellIdx(i)}];
    end

    meanArea = mean(allAreas);
    semArea = std(allAreas)/sqrt(length(allAreas));

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


  function makeFrequencyHistogram(dataIdx)
    figure
    hist(data(dataIdx).eventFreq,10)
    xlabel('Frequency (Hz)')
    ylabel('Bin count')

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function makeOneRasterPlot(dataIdx)

    % Start by plotting the traceSum
    
    hold off
    
    if(dispInfo.showClusterSum)
      area(((1:length(data(dataIdx).traceSum))-floor(length(detection.kernel)/2))/data(dataIdx).freq, ...
           data(dataIdx).traceSum,'facecolor',[1 1 1]*0.5, ...
           'edgecolor', [1 1 1]*0.5)
      hold on
      plot([0 data(dataIdx).numFrames/data(dataIdx).freq], ...
           data(dataIdx).traceSumThreshold*[1 1], ...
           'color', [0.3 1 0.3]);
    end
    
    % Then plot raster events, and then events
        
    for iN=1:length(data(dataIdx).eventStartIdx)
      iNeuron = data(dataIdx).rasterOrder(iN);

      if(dispInfo.onlyMarkStart)
        coords = data(dataIdx).eventStartIdx{iNeuron} ...
 	          / data(dataIdx).freq;
        coords = transpose(coords);

        plot(coords, iN*ones(size(coords)), ...
 	     'color', data(dataIdx).neuronColor(iNeuron,:), ...
	     'marker','.', 'markersize',8,'linestyle','none');

      else
        coords = [data(dataIdx).eventStartIdx{iNeuron} ...
 	          data(dataIdx).eventEndIdx{iNeuron}] / data(dataIdx).freq;

        coords = transpose(coords);
        %plot(coords, iNeuron*ones(size(coords)),'k');
        %plot(coords, iNeuron*ones(size(coords)), ...
        %	   'color', data(dataIdx).neuronColor(iNeuron,:));
        plot(coords, iN*ones(size(coords)), ...
 	     'color', data(dataIdx).neuronColor(iNeuron,:));
 
      end

      hold on
    end
 
    for iE = 1:length(data(dataIdx).clusterEvents)
      plot(data(dataIdx).clusterEvents(iE)*[1 1] / data(dataIdx).freq, ...
	   [1 data(dataIdx).numNeurons],'r-'); 
    end

    a = axis; 
    a(1) = 0; 
    a(2) = data(dataIdx).numFrames/data(dataIdx).freq;
    a(3) = 0.5; 
    a(4) = data(dataIdx).numNeurons + 0.5; 
    axis(a);

    xlabel('Time (s)')
    ylabel('Neuron number')
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function makeClusterRasterPlot(dataIdx,clusterIdx,markIdx)

    for iN = 1:length(data(dataIdx).neuronClusters{clusterIdx})
      iNeuron = data(dataIdx).neuronClusters{clusterIdx}(iN);
      coords = [data(dataIdx).eventStartIdx{iNeuron} ...
	        data(dataIdx).eventEndIdx{iNeuron}] / data(dataIdx).freq;

      coords = transpose(coords);
      plot(coords, iN*ones(size(coords)),'k');
      hold on
    end

    if(exist('markIdx'))
      for iN = 1:length(markIdx)
	iNeuron = data(dataIdx).neuronClusters{clusterIdx}(markIdx(iN));
        coords = [data(dataIdx).eventStartIdx{iNeuron} ...
	          data(dataIdx).eventEndIdx{iNeuron}] / data(dataIdx).freq;

        coords = transpose(coords);
        plot(coords, markIdx(iN)*ones(size(coords)),'color',[0.75 0.5 0.75]);
        hold on
      end
    end

    for iE = 1:length(data(dataIdx).clusterEvents)
      plot(data(dataIdx).clusterEvents(iE)*[1 1] / data(dataIdx).freq, ...
	   [0.5 length(data(dataIdx).neuronClusters{clusterIdx})+0.5],'r-'); 
    end

    a = axis; 
    a(1) = 0; 
    a(2) = data(dataIdx).numFrames/data(dataIdx).freq;
    a(3) = 0.5; 
    a(4) = length(data(dataIdx).neuronClusters{clusterIdx}) + 0.5; 
    axis(a);

    xlabel('Time (s)')
    ylabel('Neuron number')

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function distanceDistribution(dataIdx)

    xDist = repmat(data(dataIdx).xRes*data(dataIdx).centroid(:,1), ...
		   1,length(data(dataIdx).centroid)) ...
	   - repmat(data(dataIdx).xRes*transpose(data(dataIdx).centroid(:,1)), ...
		    length(data(dataIdx).centroid),1);
    yDist = repmat(data(dataIdx).yRes*data(dataIdx).centroid(:,2), ...
		   1,length(data(dataIdx).centroid)) ...
           - repmat(data(dataIdx).yRes*transpose(data(dataIdx).centroid(:,2)), ...
		    length(data(dataIdx).centroid),1);

    neuronDist = sqrt(xDist.^2 + yDist.^2);

    % Remove lower diagonal
    neuronDist = neuronDist + tril(NaN*neuronDist);

    figure, hist(neuronDist(:),30)
    xlabel('Distance between neurons')
    ylabel('Bin count')

    saveas(gcf, 'FIGS/dist-distrib.pdf', 'pdf');


  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % This function uses the meta data to group the slices after age
  % and conditions and then calculate different network properties

  function makeNetworkEvolutionData()

    clear networkData tmpMetaAge tmpMetaGenotype tmpMetaCondition

    networkData = struct('genotype', [], 'condition', [], 'age', 0, ...
			 'pairFreqTotal', 0, 'pairFreqTotalShuffle', 0, ...
			 'eventFreqActive', 0,  ...
			 'eventFreqActiveStdE', 0);


    % Find unique genotypes and conditions, then for each of them
    % find how much age data we have.

    clear tmpMetaAge tmpMetaGenotype tmpMetaCondition
    metaOk = ones(1,length(data));

    for i = 1:length(data)
      try
        tmpMetaAge(i) = data(i).meta.age;
        tmpMetaGenotype{i} = data(i).meta.genotype;
        tmpMetaCondition{i} = data(i).meta.condition;

        if(isnan(tmpMetaAge(i)))
	  metaOk(i) = 0;
        end

        if(isempty(tmpMetaGenotype{i}))
	  metaOk(i) = 0;
        end

        if(isempty(tmpMetaCondition{i}))
	  metaOk(i) = 0;
	end

      catch exception
        metaOk(i) = 0;
        disp('Did you forget to specify age, genotype or condition?')
        disp(sprintf('Check %s', data(i).dataName))
        %disp('Disabling network evolution plots')
        %beep
        %networkData = [];
        %disp(getReport(exception))
        %return
      end
    end

    metaOkIdx = find(metaOk);

    if(isempty(metaOkIdx))
      disp('No traces with meta data found')
      return
    end

try
    uGenotype = unique(tmpMetaGenotype(metaOkIdx));
    uCondition = unique(tmpMetaCondition(metaOkIdx));
catch e
getReport(e)
keyboard
end   
 
    typeCtr = 1;

    for iG = 1:length(uGenotype)
      for iC = 1:length(uCondition)
        maskG = cellfind(tmpMetaGenotype,uGenotype(iG));
        maskC = cellfind(tmpMetaCondition, uCondition(iC));

        try
	idx = intersect(intersect(maskG,maskC),metaOkIdx);
        catch
  	  disp('Oops...')
          keyboard
        end

        uAge = unique(tmpMetaAge(idx));

        if(isempty(uAge))
          % Skip this since no data points
          continue
        end

        clear tmpNetData
        tmpNetData.genotype = uGenotype{iG};
        tmpNetData.condition = uCondition{iC};
        tmpNetData.age = uAge;
        tmpNetData.pairFreqTotal = zeros(size(uAge));
        tmpNetData.pairFreqTotalShuffle = zeros(size(uAge));

        for iA = 1:length(uAge)
	  % Index of data with the current condition, genotype and age
          idxA = idx(find(tmpMetaAge(idx) == uAge(iA)));

          % Count pairs

          pFreq = zeros(size(detection.distEdges));
          pFreqShuf = zeros(size(detection.distEdges));
          eFreqActive = [];

          for i = 1:length(idxA)
            % If there is no data for that slice at the distance
	    % the value is NaN, we set it to zero so we can sum slices
	    tmp = data(idxA(i)).pairFreq;
            tmp(isnan(tmp)) = 0;
            pFreq = pFreq + tmp;

            tmp = data(idxA(i)).pairFreqShuffle;
            tmp(isnan(tmp)) = 0;
            pFreqShuf = pFreqShuf + tmp;
            idxE = find(data(idxA(i)).eventFreq > 0);
            eFreqActive = [eFreqActive; data(idxA(i)).eventFreq(idxE)];
          end          

	  tmpNetData.pairFreqTotal(iA) = sum(pFreq);
          tmpNetData.pairFreqTotalShuffle(iA) = sum(pFreqShuf);
          tmpNetData.eventFreqActive(iA) = mean(eFreqActive);
          tmpNetData.eventFreqActiveStdE(iA) = ...
	    std(eFreqActive) / sqrt(length(eFreqActive));

        end

        try
  	  networkData(typeCtr) = tmpNetData;
        catch exception
  	  disp('So sorry, oops!')
  	  getReport(exception)
          keyboard
        end

        typeCtr = typeCtr + 1;
      end
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function cellFindMask = cellfind(cellArray,str)
    cellFindMask = find(cellfun(@(x) strcmp(str,x), cellArray));
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function plotNetworkEvolutionPairFreq(dummyIdx)

    if(isempty(networkData))
      disp('Unable to generate age-plots')
      return
    end

    % This function ignores dummydx, uses data from all loaded
    updateGUI(); % Mark all files as selected

    lineColors = [0 0 0; 0.031 0.05 0.32; 0 0 1; 0.14 0.79 1; ...
		    1 0 0; 1 0.66 0; 1 0 1; 0 1 0.6];
    lineTypes = {'-'};% { '-', '--' };

    clear p pLeg

    for i = 1:length(networkData)
      p(i) = plot(networkData(i).age, ...
		  networkData(i).pairFreqTotal ...
		  ./networkData(i).pairFreqTotalShuffle, ...
		  'color', lineColors(mod(i-1,size(lineColors,1))+1,:), ...
		  'linestyle',lineTypes{mod(i-1,length(lineTypes))+1});
      hold on
      pLeg{i} = sprintf('%s %s', ...
			networkData(i).genotype, ...
			networkData(i).condition);
    end

    legend(p,pLeg)
    xlabel('Age (days)')
    ylabel('Spike pairs (relative to shuffled)')

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function plotNetworkEvolutionEventFreqActive(dummyIdx)

    if(isempty(networkData))
      disp('Unable to generate age-plots')
      return
    end

    % This function ignores dummyIdx, sets all as selected
    updateGUI();

    lineColors = [0 0 0; 1 0 0; 0 1 0; 0 0 1];
    lineTypes = { '-', '--' };

    clear p pLeg

    for i = 1:length(networkData)
      errorbar(networkData(i).age, ...
	       networkData(i).eventFreqActive, ...
	       networkData(i).eventFreqActiveStdE,'k.');	        
      hold on
    end

    for i = 1:length(networkData)
      p(i) = plot(networkData(i).age, ...
		  networkData(i).eventFreqActive, ...
		  'color', lineColors(mod(i-1,size(lineColors,1))+1,:), ...
		  'linestyle',lineTypes{mod(i-1,length(lineTypes))+1});

      pLeg{i} = sprintf('%s %s', ...
			networkData(i).genotype, ...
			networkData(i).condition);
    end

    legend(p,pLeg)
    xlabel('Age (days)')
    ylabel('Frequency, active neurons (Hz)')    

  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %%% Cross-correlation

  function ISI = calcISI(eventsA, eventsB)
    if(isempty(eventsA) | isempty(eventsB))
      ISI = [];
    else
      ISI = repmat(eventsA,1,size(eventsB,1)) ...
	   - repmat(transpose(eventsB),size(eventsA,1),1);
      ISI = ISI(:);
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function [crossCorr, shuffleCrossCorr] = ...
    crossCorrelogramDistanceRange(dataIdx, minDist, maxDist)

    disp(sprintf('Calculating cross correlogram for %d',dataIdx))

    nNeigh = 0;

    crossCorr = zeros(size(detection.CCedges));
    shuffleCrossCorr = zeros(size(detection.CCedges));

    for i=1:length(data(dataIdx).eventStartIdx)
      xDist = data(dataIdx).centroid(:,1) - data(dataIdx).centroid(i,1);
      yDist = data(dataIdx).centroid(:,2) - data(dataIdx).centroid(i,2);
      neuronDist = sqrt((data(dataIdx).xRes*xDist).^2 ...
			+ (data(dataIdx).yRes*yDist).^2);

      % Exclude self comparisons
      neuronDist(i) = NaN;

      idx = find(minDist <= neuronDist & neuronDist <= maxDist);
      nNeigh = nNeigh + length(idx);

      for j=1:length(idx)
        ISI = calcISI(data(dataIdx).eventStartIdx{i}, ...
		      data(dataIdx).eventStartIdx{idx(j)});

        sISI = calcISI(shuffleISI(data(dataIdx).eventStartIdx{i}, ...
				  data(dataIdx).numFrames), ...
		       shuffleISI(data(dataIdx).eventStartIdx{idx(j)}, ...
				  data(dataIdx).numFrames));

        if(~isempty(ISI))
          % The extra transpose here are since if there is just one
          % element in ISI, then histc will return a row vector instead
          % of a column vector.
          [n, bin] = histc(transpose(ISI),detection.CCedges);
          [ns, bins] = histc(transpose(sISI),detection.CCedges);

          crossCorr = crossCorr + transpose(n);
          shuffleCrossCorr = shuffleCrossCorr + transpose(ns);
        end
      end
    end

    edges = detection.CCedges;

    % Skipping normalisation
    % % Normalise by total time (number of neighbours * maxTime per neighbour)
    % crossCorr = crossCorr/(nNeigh*data(dataIdx).numFrames);
    % shuffleCrossCorr = shuffleCrossCorr/(nNeigh*data(dataIdx).numFrames);

    if(~nnz(crossCorr))
      disp(['WARNING: No events within +/- 40 frames of each other. Cross ' ...
            'correlogram empty'])
    end
        
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function peakIdx = findLocalPeaks(trace, minThresh)

    if(size(trace,1) > 1)
      trace = transpose(trace);
    end

    trace(trace < minThresh) = minThresh;

    % Peak is larger than element to the right
    rightMask = [trace(1:end-1) >= trace(2:end), 1];

    % Peak is larger than element to the left
    leftMask = [1, trace(2:end) >= trace(1:end-1)]; 

    peakMask = rightMask & leftMask;

    % Make sure there are not two points after each other that are peaks
    peakMask = [peakMask(1), peakMask(2:end) & ~peakMask(1:end-1)];

    % Peaks are higher than minThresh
    peakMask = peakMask & trace > minThresh;

    peakIdx = find(peakMask);

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % This function places a kernel around all events in the slice, sums them together
  % and find the local maximas above a threshold. This threshold is determined by
  % shuffling the original kernel-multipliedtraces.

  function findClusterEvents(dataIdx)

    disp('Locating cluster events')

    nShuffle = 500; % 10000

    eventSum = zeros(data(dataIdx).numFrames,1);
    maxEventsShuffled = zeros(nShuffle,1);

    for iE = 1:length(data(dataIdx).eventStartIdx)
      eventSum(data(dataIdx).eventStartIdx{iE}) = ...
          eventSum(data(dataIdx).eventStartIdx{iE}) + 1;
    end

    traceSum = addKernel(eventSum);

    for iS = 1:nShuffle
      maxEventsShuffled(iS) = max(makeShuffleSum(dataIdx));
    end

    % We estimate a threshold by finding all the shuffled traces max value
    % calculating mean and std of that max values, and taking 
    % mean + N*std as the threshold.

    meanShuffleMax = mean(maxEventsShuffled);
    stdShuffleMax = std(maxEventsShuffled);

    synchThreshold = meanShuffleMax + detection.nStdCluster*stdShuffleMax;
    peakLoc = findLocalPeaks(traceSum, synchThreshold);

    % Old way to find peakLoc, it misses double peaks when two are the same
    %traceSumFilt = traceSum;
    %traceSumFilt(traceSumFilt < synchThreshold) = synchThreshold;
    %[peakVals, peakLoc] = findpeaks(traceSumFilt);


    data(dataIdx).clusterEvents = peakLoc - floor(length(detection.kernel)/2);
    
    data(dataIdx).traceSum = traceSum;
    data(dataIdx).traceSumThreshold = synchThreshold;
    
    if(0 & dispInfo.showClusterSum)
        % Disabled this plot, using showClusterSum for raster plot now
      f = gcf;
      figure
      title(data(dataIdx).maskFile)
      sp(1) = subplot(2,1,1);

      for iP = 1:length(data(dataIdx).clusterEvents)
        plot(data(dataIdx).clusterEvents(iP)*[1 1]/data(dataIdx).freq, ...
             [1 data(dataIdx).numNeurons],'r-')
        hold on
      end

      for iP = 1:length(data(dataIdx).eventStartIdx)
        
        % Need to run this twice to get the correct colouring
        if(isempty(data(dataIdx).neuronClusters))
          col = [1 0 0];
        else
          if(ismember(iP,data(dataIdx).neuronClusters{1}))
            col = [0 0 0];
          else
            col = [1 1 1]*0.6;
          end
        end
        
        %if(ismember(iP,data(dataIdx).specialIdx))
        %  col = 'y.';
        %else
        %  col = 'k.';
        %end

        plot(data(dataIdx).eventStartIdx{iP}/data(dataIdx).freq, ...
             iP*ones(size(data(dataIdx).eventStartIdx{iP})),'.','color',col)
        hold on
      end       
 
      box off
      set(gca,'fontsize',20)
      xlabel('Time (s)','fontsize',24)
      ylabel('Cell','fontsize',24)
      
      sp(2) = subplot(2,1,2);
      % We have to subtract the kernel halfwidth
      plot(((1:length(traceSum))-floor(length(detection.kernel)/2))/data(dataIdx).freq,traceSum,'k-')
      hold on
      plot([1 length(traceSum)]/data(dataIdx).freq,synchThreshold*[1 1],'r-')

      box off
      set(gca,'fontsize',20)
      xlabel('Time (s)','fontsize',24)
      ylabel('Count','fontsize',24)
      
      linkaxes(sp,'x')

      figure(f);
    end


  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % This uses the shared network events to cluster the neurons

  function clusterNeurons(dataIdx)

    binTrace = zeros(data(dataIdx).numFrames,1);
    binTrace(data(dataIdx).clusterEvents) = 1;
    clusterTrace = addKernel(binTrace);
    maxScore = sum(clusterTrace.*clusterTrace);
    score = zeros(data(dataIdx).numNeurons,1);

    clusterFlag = zeros(data(dataIdx).numNeurons,1);

    for iN = 1:length(data(dataIdx).eventStartIdx)
      binTrace = zeros(data(dataIdx).numFrames,1);
      binTrace(data(dataIdx).eventStartIdx{iN}) = 1;
      score(iN) = sum(clusterTrace.*addKernel(binTrace));
    end

    clusterFlag(find(score/maxScore > detection.participationThreshold)) = 1;

    data(dataIdx).neuronClusters = { find(clusterFlag) };

    fprintf('Slice %d: Found cluster of size %d\n', ...
	    dataIdx, nnz(clusterFlag))

    % Write the cluster mask
    data(dataIdx).clusterMask = zeros(data(dataIdx).height, ...
				      data(dataIdx).width);
    
    for iCl = 1:length(data(dataIdx).neuronClusters)
      for iN = 1:length(data(dataIdx).neuronClusters{iCl})
        idxN = data(dataIdx).neuronClusters{iCl}(iN);
        data(dataIdx).clusterMask(data(dataIdx).pixelList{idxN}) = iCl;
      end
    end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function calculateNeuronParticipation(dataIdx)

    if(isempty(data(dataIdx).neuronClusters))
      disp('No cluster')
      data(dataIdx).meanNeuronParticipation = 0;
      data(dataIdx).SEMNeuronParticipation = 0;
      data(dataIdx).clusterFrequency = 0;
      return
    end

    data(dataIdx).neuronParticipation = zeros(data(dataIdx).numNeurons,1);

    allClusterEventAmp = [];

    % Exclude special cells from this statistics
    nonSpecialIdx = setdiff(1:data(dataIdx).numNeurons, ...
			      data(dataIdx).specialIdx);
    
    %for i = 1:length(data(dataIdx).eventStartIdx)
    for iSpec = 1:length(nonSpecialIdx)
      i = nonSpecialIdx(iSpec);
      
      if(isempty(data(dataIdx).eventStartIdx{i}))
        data(dataIdx).neuronParticipation(i) = NaN;
      else

	clusterParticipationFlag = zeros(size(data(dataIdx).clusterEvents));

        for j = 1:length(data(dataIdx).clusterEvents)

	  idx = find(data(dataIdx).clusterEvents(j) - detection.pairDt ...
		     <= data(dataIdx).eventStartIdx{i} ...
		     & data(dataIdx).eventStartIdx{i} ...
		     <= data(dataIdx).clusterEvents(j) + detection.pairDt);

          if(~isempty(idx))
            clusterParticipationFlag(j) = 1;
            try
              allClusterEventAmp = ...
 	        [allClusterEventAmp; data(dataIdx).eventAmplitude{i}(idx)];
            catch e
	      getReport(e)
              keyboard
            end
          end
        end        

	data(dataIdx).neuronParticipation(i) = ...
	  sum(clusterParticipationFlag) / length(clusterParticipationFlag);
      end

    end

    idx = data(dataIdx).neuronClusters{1};
    data(dataIdx).meanNeuronParticipation = ...
      mean(data(dataIdx).neuronParticipation(idx));
    data(dataIdx).SEMNeuronParticipation = ...
      std(data(dataIdx).neuronParticipation(idx))/sqrt(length(idx));

    % Average size of the events that are at the time of the cluster events
    data(dataIdx).meanClusterEventAmplitude = mean(allClusterEventAmp);
    data(dataIdx).semClusterEventAmplitude = std(allClusterEventAmp) ...
                                             /length(allClusterEventAmp);  


    data(dataIdx).clusterFrequency = ...
      length(data(dataIdx).clusterEvents) ...
      / (data(dataIdx).numFrames / data(dataIdx).freq);
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function calculateTransferEntropy(dataIdx)

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function calculateTransferEntropyPair(dataIdx,neuronA,neuronB)

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % This calculates the P(i_n+1,i_n,j_n) matrix
  % to be used for transfer entropy

  function calcPmatrix(dataIdx, binEdges, neuronIdxA, neuronIdxB)

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % This function calculates when a neuron fires in relation to the cluster events

  function calculateNeuronPhase(dataIdx)

    % !!!!

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function countPairFreq(pairDataIdx, distEdges, pairDt)

    disp(sprintf('Calculating pair frequency vs distance, data %d', pairDataIdx))

    pairFreq = NaN*distEdges;
    pairFreqS = NaN*distEdges;

    for k=1:length(distEdges)-1
      minDist = distEdges(k);
      maxDist = distEdges(k+1);

      pairCount = 0;
      pairCountShuffle = 0;
      nNeigh = 0;

      for i=1:length(data(pairDataIdx).eventStartIdx)

        xDist = data(pairDataIdx).xRes*(data(pairDataIdx).centroid(:,1) ...
			                - data(pairDataIdx).centroid(i,1));
        yDist = data(pairDataIdx).yRes*(data(pairDataIdx).centroid(:,2) ...
			                 - data(pairDataIdx).centroid(i,2));
        neuronDist = sqrt(xDist.^2 + yDist.^2);

        % Exclude self comparisons
        neuronDist(i) = NaN;

        idx = find(minDist <= neuronDist & neuronDist <= maxDist);
        nNeigh = nNeigh + length(idx);

        % Put all the ISI together into one large vector
        for j=1:length(idx)

          ISI = calcISI(data(pairDataIdx).eventStartIdx{i}, ...
			data(pairDataIdx).eventStartIdx{idx(j)});

          pairCount = pairCount + length(find(abs(ISI) <= pairDt));

          sISI = calcISI(shuffleISI(data(pairDataIdx).eventStartIdx{i}, ...
				    data(pairDataIdx).numFrames), ...
			 shuffleISI(data(pairDataIdx).eventStartIdx{idx(j)}, ...
				    data(pairDataIdx).numFrames));

          pairCountShuffle = pairCountShuffle + length(find(abs(sISI) <= pairDt));

        end

      end

      % We use abs since we want those that are within pairDt frames
      % and we do not care about order the neurons are activated.
      nToFreq = 1/(nNeigh*data(pairDataIdx).numFrames/data(pairDataIdx).freq);

      pairFreq(k) = pairCount * nToFreq;
      pairFreqS(k) = pairCountShuffle * nToFreq;

    end

    data(pairDataIdx).pairFreq = pairFreq;
    data(pairDataIdx).pairFreqShuffle = pairFreqS;

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % This function calculates how many neurons of different types are
  % at a specific distance.

  function calculateNeighbourDistanceDistribution(dataIdx,distEdges)

    % !!! Should this be normalised by number of center 
    %     neurons we look around?
    % !!! Add error bars if viewing more than one slice?

    disp('Calculating neighbour distance distributions')

    for i = 1:length(dataIdx)
      
      dIdx = dataIdx(i);

      numNeurons = data(dIdx).numNeurons;

      allDistX = repmat(data(dIdx).centroid(:,1),1,numNeurons) ...
          -repmat(transpose(data(dIdx).centroid(:,1)),numNeurons,1);

      allDistY = repmat(data(dIdx).centroid(:,2),1,numNeurons) ...
          -repmat(transpose(data(dIdx).centroid(:,2)),numNeurons,1);

      allDist = sqrt(allDistX.^2 + allDistY.^2);

      % Mark the diagonals as NaN, no self counting
      allDist = allDist + diag(diag(allDist)*NaN);

      % Now we want to make a histogram of the distances from a silent
      % neuron to all its silent neighbours, then also calculate 
      % normalisation with respect to all other neurons.

      silentIdx       = find(data(dIdx).eventFreq == 0);
      nonSilentIdx = setdiff(1:data(dIdx).numNeurons,silentIdx);
      
      silentDist      = allDist(silentIdx,silentIdx);
      silentDistRef   = allDist(silentIdx,nonSilentIdx);
      nSilentDist     = histc(silentDist(:),distEdges) / numel(silentIdx);
      nSilentDistRef  = histc(silentDistRef(:),distEdges) / numel(silentIdx);

      % *** Should we normalise by the number of neurons?

      % Do the same for special neurons

      nonSpecialIdx = setdiff(1:data(dIdx).numNeurons,data(dIdx).specialIdx);
      
      specialDist     = allDist(data(dIdx).specialIdx, ...
                                data(dIdx).specialIdx);
      specialDistRef  = allDist(data(dIdx).specialIdx,nonSpecialIdx);
      nSpecialDist    = histc(specialDist(:),distEdges) / numel(data(dIdx).specialIdx);
      nSpecialDistRef = histc(specialDistRef(:),distEdges) / numel(data(dIdx).specialIdx);

      % Also for the clustered neurons
      % Here we do the calculation for each cluster individually
      % then we group the data together.

      nClusterDist        = zeros(size(distEdges));
      nClusterDistRef     = zeros(size(distEdges));
      nClusterDistShuffle = zeros(size(distEdges));
      
      nShuffle = 500;
      
      nClust = 0;
      nClustShuf = 0;
      
      clusterDistAll = [];
      clusterDistAllRef = [];
      clusterDistAllShuffle = [];
      
      for j = 1:length(data(dIdx).neuronClusters)
        clusterIdx      = data(dIdx).neuronClusters{j};
        nonClusterIdx = setdiff(1:data(dIdx).numNeurons, clusterIdx);
        
        clusterDist     = allDist(clusterIdx,clusterIdx);
        clusterDistRef  = allDist(clusterIdx,nonClusterIdx);

        clusterDistAll = [clusterDistAll; clusterDist(:)];
        clusterDistAllRef = [clusterDistAllRef; clusterDistRef(:)];
        
        if(~isempty(clusterDist) & nnz(~isnan(clusterDist)))
          nClusterDist = nClusterDist ...
              + histc(clusterDist(:),distEdges);
          nClusterDistRef = nClusterDistRef ...
              + histc(clusterDistRef(:),distEdges);
        end
        
        nClust = nClust + numel(clusterIdx);

        % Now we need to do shuffle
        
        for k = 1:nShuffle
          shufIdx = randperm(data(dIdx).numNeurons);
          shufIdx = shufIdx(1:numel(clusterIdx));
          %restIdx = setdiff(1:data(dIdx).numNeurons,shufIdx);
          
          % clusterDistShuf = allDist(shufIdx,restIdx);
          clusterDistShuf = allDist(shufIdx,shufIdx);          
          
          clusterDistAllShuffle = [clusterDistAllShuffle; clusterDistShuf(:)];
          
          nClusterDistShuffle = nClusterDistShuffle ...
              + histc(clusterDistShuf(:),distEdges);
          
          nClustShuf = nClustShuf + numel(shufIdx);
        end
        
      end

      % Normalise by number of clustered neurons
      nClusterDist = nClusterDist / nClust;
      nClusterDistRef = nClusterDistRef / nClust;
      nClusterDistShuffle = nClusterDistShuffle / nClustShuf;
      
      data(dIdx).nSilentDist = nSilentDist;
      data(dIdx).nSilentDistRef = nSilentDistRef;
      data(dIdx).nSpecialDist = nSpecialDist;
      data(dIdx).nSpecialDistRef = nSpecialDistRef;
      data(dIdx).nClusterDist = nClusterDist;
      data(dIdx).nClusterDistRef = nClusterDistRef;
      data(dIdx).nClusterDistShuffle = nClusterDistShuffle;      

      % Save raw distance values also
      data(dIdx).silentDistAll = silentDist;
      data(dIdx).silentDistAllRef = silentDistRef;
      data(dIdx).specialDistAll = specialDist;
      data(dIdx).specialDistAllRef = specialDistRef;
      data(dIdx).clusterDistAll = clusterDistAll;
      data(dIdx).clusterDistAllRef = clusterDistAllRef;
      data(dIdx).clusterDistAllShuffle = clusterDistAllShuffle;
      
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function showNeighbourDistanceDistribution(dataIdx,neighbourType)

    switch(neighbourType)
      case 'silent'

        allSilent = zeros(numel(detection.distEdges),numel(dataIdx));
        allSilentRef = zeros(numel(detection.distEdges),numel(dataIdx));

        for i = 1:length(dataIdx);
          allSilent(:,i) = data(dataIdx(i)).nSilentDist;
          allSilentRef(:,i) = data(dataIdx(i)).nSilentDistRef;
        end

        p = stairs(detection.distEdges, nanmean(allSilent,2), ...
                   'k-','linewidth',3); hold on
        p(2) = stairs(detection.distEdges,nanmean(allSilentRef,2), ...
                      'k--','linewidth',3);
        box off

        % Add axis to right side for relative curve
        axL = gca;
        axR = axes;

        p(3) = stairs(detection.distEdges,...
                      nanmean(allSilent./allSilentRef,2), ...
                      'r','linewidth',3,'parent',axR);
        
        set(axR,'units',get(axL,'units'));
        set(axR,'position',get(axL,'position'));
        set(axR,'YaxisLocation','right');
        set(axR,'color','none')
        a = axis; a(3:4) = [0 1]; axis(a);
        box off
        
        legend(p,'Silent','Reference','Relative difference')
        xlabel('Distance (\mum)')
        ylabel('Count')

        handles.plotRightAxis = axR;

      case 'special'

        allSpecial = zeros(numel(detection.distEdges),numel(dataIdx));
        allSpecialRef = zeros(numel(detection.distEdges),numel(dataIdx));

        for i = 1:length(dataIdx)
          allSpecial(:,i) = data(dataIdx(i)).nSpecialDist;
          allSpecialRef(:,i) = data(dataIdx(i)).nSpecialDistRef;
        end

        p = stairs(detection.distEdges, nanmean(allSpecial,2), ...
                   'k-','linewidth',3); hold on
        p(2) = stairs(detection.distEdges,nanmean(allSpecialRef,2), ...
                      'k--','linewidth',3); 

        box off

        % Add axis to right side for relative curve
        axL = gca;
        axR = axes;

        p(3) = stairs(detection.distEdges,...
                      nanmean(allSpecial./allSpecialRef,2), ...
                      'r','linewidth',3,'parent',axR);
        
        set(axR,'units',get(axL,'units'));
        set(axR,'position',get(axL,'position'));
        set(axR,'YaxisLocation','right');
        set(axR,'color','none')
        a = axis; a(3:4) = [0 1]; axis(a);
        box off

        legend(p,'Special','Reference', 'Relative difference')

        xlabel('Distance (\mum)')
        ylabel('Count')

        handles.plotRightAxis = axR;

      case 'clustershuffled'

        allCluster = zeros(numel(detection.distEdges),numel(dataIdx));
        allClusterRef = zeros(numel(detection.distEdges),numel(dataIdx));
        allClusterShuffle = zeros(numel(detection.distEdges),numel(dataIdx));
        
        allDistCluster = [];
        allDistClusterRef = [];
        allDistClusterShuffle = [];
        
        for i = 1:length(dataIdx)
          allCluster(:,i) = data(dataIdx(i)).nClusterDist;
          allClusterRef(:,i) = data(dataIdx(i)).nClusterDistRef;
          allClusterShuffle(:,i) = data(dataIdx(i)).nClusterDistShuffle; ...
              
              
          allDistCluster = [allDistCluster; data(dataIdx(i)).clusterDistAll];
          allDistClusterRef = [allDistClusterRef; data(dataIdx(i)).clusterDistAllRef];
          allDistClusterShuffle = [allDistClusterShuffle; data(dataIdx(i)).clusterDistAllShuffle];
          
        end

        p = stairs(detection.distEdges, nanmean(allCluster,2), ...
                   'k-','linewidth',3); hold on
        p(2) = stairs(detection.distEdges,nanmean(allClusterShuffle,2), ...
                      'k--','linewidth',3);
        %stairs(detection.distEdges,nanmean(allClusterRef,2), ...
        %              'k:','linewidth',3);

        box off
        ylabel('Average #neighbours')

        % Add axis to right side for relative curve
        axL = gca;
        axR = axes;

        % v1 = allCluster(~isnan(allCluster(:)));
        % v2 = allClusterShuffle(~isnan(allClusterShuffle));
        v1 = allDistCluster(~isnan(allDistCluster(:)));
        v2 = allDistClusterShuffle(~isnan(allDistClusterShuffle));

        [hks,pks,ks2statS] = kstest2(v1,v2);
        
        title(sprintf('P_{KS} = %d', pks))
        
        points = (detection.distEdges(1:end-1) + ...
                     detection.distEdges(2:end))/2;
        
        % Only count non NaN numbers for the SEM
        %semVal = nanstd(allCluster./allClusterRef,[],2) ...
        %         ./ sqrt(sum(~isnan(allCluster./allClusterRef),2));
        semVal = nanstd(allCluster./allClusterShuffle,[],2) ...
                 ./ sqrt(sum(~isnan(allCluster./allClusterShuffle),2));
        
        semVal = semVal(1:end-1);
        %meanVal = nanmean(allCluster./allClusterRef,2);
        meanVal = nanmean(allCluster./allClusterShuffle,2);        
        meanVal = meanVal(1:end-1);       

        errorbar(points,meanVal,semVal,'r.')
        
        hold on
        % p(3) = stairs(detection.distEdges,...
        %               nanmean(allCluster./allClusterRef,2), ...
        %               'r','linewidth',3,'parent',axR);
        p(3) = stairs(detection.distEdges,...
                      nanmean(allCluster./allClusterShuffle,2), ...
                      'r','linewidth',3,'parent',axR);

        
        
        set(axR,'units',get(axL,'units'));
        set(axR,'position',get(axL,'position'));
        set(axR,'YaxisLocation','right');
        set(axR,'color','none')
        % a = axis; a(3:4) = [0 1]; axis(a);
        box off

        distEdges = detection.distEdges;
        % ratio = nanmean(allCluster./allClusterRef,2);
        % ratioSEM = nanstd(allCluster./allClusterRef,[],2) / sqrt(size(allCluster,2));
        ratio = nanmean(allCluster./allClusterShuffle,2);
        ratioSEM = nanstd(allCluster./allClusterShuffle,[],2) / sqrt(size(allCluster,2));
        save('spatial-cluster-shuffle-data.mat', ...
             'distEdges','allCluster','allClusterRef', 'allClusterShuffle',...
             'ratio', 'ratioSEM','pks','ks2statS')
        
        try
          legend(p,'Cluster members','Reference (shuffled)', ...
                 sprintf('Relative difference P_{KS} = %.1d', pks))
          xlabel('Distance (\mum)')
          ylabel('Ratio #clust neigh / # shuffled reference')
        catch e
          getReport(e)
          keyboard
        end
        
        handles.plotRightAxis = axR;

      case 'cluster'

        allCluster = zeros(numel(detection.distEdges),numel(dataIdx));
        allClusterRef = zeros(numel(detection.distEdges),numel(dataIdx));

        allDistCluster = [];
        allDistClusterRef = [];        
        
        for i = 1:length(dataIdx)
          allCluster(:,i) = data(dataIdx(i)).nClusterDist;
          allClusterRef(:,i) = data(dataIdx(i)).nClusterDistRef;
          
          allDistCluster = [allDistCluster; data(dataIdx(i)).clusterDistAll];
          allDistClusterRef = [allDistClusterRef; data(dataIdx(i)).clusterDistAllRef];
          
        end

        p = stairs(detection.distEdges, nanmean(allCluster,2), ...
                   'k-','linewidth',3); hold on
        p(2) = stairs(detection.distEdges,nanmean(allClusterRef,2), ...
                      'k:','linewidth',3);

        box off
        ylabel('Average #neighbours')

        % Add axis to right side for relative curve
        axL = gca;
        axR = axes;

        % v1 = allCluster(~isnan(allCluster(:)));
        % v2 = allClusterRef(~isnan(allClusterRef(:)));
        v1 = allDistCluster(~isnan(allDistCluster(:)));
        v2 = allDistClusterRef(~isnan(allDistClusterRef));
        
        [hks,pksr,ks2statR] = kstest2(v1,v2);
        
        title(sprintf('P_{KS} = %d', pksr))
        
        points = (detection.distEdges(1:end-1) + ...
                     detection.distEdges(2:end))/2;
        
        % Only count non NaN numbers for the SEM
        semVal = nanstd(allCluster./allClusterRef,[],2) ...
                 ./ sqrt(sum(~isnan(allCluster./allClusterRef),2));
        
        semVal = semVal(1:end-1);
        meanVal = nanmean(allCluster./allClusterRef,2);
        meanVal = meanVal(1:end-1);       

        errorbar(points,meanVal,semVal,'r.')
        
        hold on
        p(3) = stairs(detection.distEdges,...
                      nanmean(allCluster./allClusterRef,2), ...
                      'r','linewidth',3,'parent',axR);
        
        
        set(axR,'units',get(axL,'units'));
        set(axR,'position',get(axL,'position'));
        set(axR,'YaxisLocation','right');
        set(axR,'color','none')
        % a = axis; a(3:4) = [0 1]; axis(a);
        box off

        distEdges = detection.distEdges;
        ratio = nanmean(allCluster./allClusterRef,2);
        ratioSEM = nanstd(allCluster./allClusterRef,[],2) / sqrt(size(allCluster,2));
        save('spatial-cluster-ref-data.mat', ...
             'distEdges','allCluster','allClusterRef', ...
             'ratio', 'ratioSEM','pksr','ks2statR')
        
        try
          legend(p,'Cluster members','Reference (non-clustered)', ...
                 sprintf('Relative difference P_{KS} = %.1d', pksr))
          xlabel('Distance (\mum)')
          ylabel('Ratio #clust neigh / # non-clustered reference')
        catch e
          getReport(e)
          keyboard
        end
        
        handles.plotRightAxis = axR;
        
        
      otherwise
        disp('Unknown neighbour type, aborting.')
        return
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function plotSpatialClusteringAlt(dataIdx)
    
    meanClustNeighDist = zeros(numel(dataIdx),1);
    meanShuffleNeighDist = zeros(numel(dataIdx),1);
    % meanNonClustNeighDist = zeros(numel(dataIdx),1);
    
    nShuffle = 500;
    
    for i = 1:numel(dataIdx)
      
      dIdx = dataIdx(i);

      numNeurons = data(dIdx).numNeurons;

      allDistX = repmat(data(dIdx).centroid(:,1),1,numNeurons) ...
          -repmat(transpose(data(dIdx).centroid(:,1)),numNeurons,1);

      allDistY = repmat(data(dIdx).centroid(:,2),1,numNeurons) ...
          -repmat(transpose(data(dIdx).centroid(:,2)),numNeurons,1);

      allDist = sqrt(allDistX.^2 + allDistY.^2);

      % Mark the diagonals as NaN, no self counting
      allDist = allDist + diag(diag(allDist)*NaN);

      % This code only handles one cluster!!
      assert(numel(data(dIdx).neuronClusters) == 1);
      
      clusterIdx = data(dIdx).neuronClusters{1};
      % nonClusterIdx = setdiff(1:data(dIdx).numNeurons,clusterIdx);
      
      DC = allDist(clusterIdx,clusterIdx);
      % DNC = allDist(clusterIdx,nonClusterIdx);
      
      DSC = [];
      for j = 1:nShuffle
        shuffleIdx = randperm(numNeurons);
        shuffleIdx = shuffleIdx(1:numel(clusterIdx));
        shufDist = allDist(shuffleIdx,shuffleIdx);
        DSC = [DSC(:); shufDist(:)];
      end
      
      meanClusterNeighDist(i,1) = nanmean(DC(:));
      % meanNonClusterNeighDist(i,1) = nanmean(DNC(:));
      meanShuffleNeighDist(i,1) = nanmean(DSC(:));
               
      if(isnan(nanmean(DC(:))))
        disp('Something weird... a NaN')
        beep
        keyboard
      end
      
    end

    errorbar(1:2, ...
             [nanmean(meanClusterNeighDist) nanmean(meanShuffleNeighDist)], ...
             [nanstd(meanClusterNeighDist) / sqrt(nnz(~isnan(meanClusterNeighDist))) ...
              nanstd(meanShuffleNeighDist) / sqrt(nnz(~isnan(meanShuffleNeighDist)))], ...
             'linestyle','none','marker','none');           
    hold on
    bar(1:2, [mean(meanClusterNeighDist) mean(meanShuffleNeighDist)])
    set(gca,'xtick',[1 2],'xticklabel', {'Cluster','Shuffled'})
    xlabel('Neighbour type','fontsize',24)
    ylabel('Mean distance','fontsize',24)
    set(gca,'fontsize',20)
    box off
    
    [H,P] = ttest(meanClusterNeighDist, meanShuffleNeighDist);
    
    title(sprintf('Two sided t-test. P = %d', P))
    
    hold off
    
    save('cluster-dist-data.mat', ...
         'meanClusterNeighDist','meanShuffleNeighDist');
    
  end

  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % This function tries to identify neurons that fire early in the phase
  % and shows their location.

  function locateEarlyNeurons(dataIdx)

    maxDist = 10;
 
    % Look at +/- 10 frames around each spike of the i:th neuron
    % and see if there are more neuronal activity in the slice before
    % than after (or vise versa)
    avgTimeDiff = NaN*zeros(data(dataIdx).numNeurons,1);
    stdTimeDiff = NaN*zeros(data(dataIdx).numNeurons,1);

    neuronColors = zeros(data(dataIdx).numNeurons,3);

    for i = 1:data(dataIdx).numNeurons
      allDiffs = zeros(0,1);

      if(numel(data(dataIdx).eventStartIdx{i}) == 0) 
        continue
      end

      % Use setdiff to avoid self comparison
      for j = setdiff(1:data(dataIdx).numNeurons,i)

        if(numel(data(dataIdx).eventStartIdx{j}) == 0) 
          continue
        end

        timeDiff = repmat(data(dataIdx).eventStartIdx{i}, ...
			  1,size(data(dataIdx).eventStartIdx{j},1)) ...
                 - repmat(transpose(data(dataIdx).eventStartIdx{j}), ...
			  size(data(dataIdx).eventStartIdx{i},1),1);

        timeDiff = timeDiff(:);
        
        idx = find(abs(timeDiff) <= maxDist);

        if(~isempty(idx))
          allDiffs = [allDiffs; timeDiff(idx)];
        end
      end

      if(isempty(allDiffs))
        avgTimeDiff(i) = NaN;
        stdTimeDiff(i) = NaN;
      else
        avgTimeDiff(i) = mean(allDiffs);
        stdTimeDiff(i) = std(allDiffs);
      end

    end


    sliceImg = ones(data(dataIdx).height,data(dataIdx).width,3);
    %colMap = colormap('cool');
    colMap = colormap('jet');


    for i = 1:data(dataIdx).numNeurons
      [y,x] = ind2sub(size(data(dataIdx).neuronMask), ... 
		      data(dataIdx).pixelList{i});

      if(isnan(avgTimeDiff(i)))
	pixelCol = [0 0 0];
      else
        % Find the colour to use for the neuron
        for k = 1:3
          pixelCol(k) = interp1(linspace(-maxDist,maxDist,64), ...
				colMap(:,k),avgTimeDiff(i));
        end
      end

      neuronColors(i,:) = pixelCol;

      for j = 1:length(x)
	sliceImg(y(j),x(j),:) = pixelCol;
      end
    end

    imshow(sliceImg)

    % Show color bar
    c = colorbar;
    ylim = get(c,'ylim');
    yticks = [-1 -0.5 0 0.5 1];
    set(c,'ytick',interp1([-1 1],ylim,yticks), ...
          'yticklabel', maxDist*yticks);

    set(handles.fig,'WindowButtonDownFcn', @handleEarlyEventSliceClick);

    if(0)
      % Show a figure with the traces coloured accordingly

      figure
      for i=1:data(dataIdx).numNeurons
        if(nnz(neuronColors(i,:)) == 0)
          continue % Skip the black uncorrelated traces
        end

        plot(data(dataIdx).relTrace(:,i),'color',neuronColors(i,:))
        %plot(data(dataIdx).relTrace(:,i),'k-')
        hold on
      end

      for i=1:data(dataIdx).numNeurons
        if(nnz(neuronColors(i,:)) == 0)
          continue % Skip the black uncorrelated traces
        end

	et = data(dataIdx).eventStartIdx{i};
        plot(et,data(dataIdx).relTrace(et,i),'k.','markersize',20);
        plot(et,data(dataIdx).relTrace(et,i),'*','color',neuronColors(i,:));


      end
    end
  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function handleEarlyEventSliceClick(source, event)

    tmpXY = get(handles.plot,'CurrentPoint');
    x = round(tmpXY(1,1));
    y = round(tmpXY(1,2));

    % Check if we are inside the slice axis
    tmpAxis = axis();
    selectIdx = allowMultiFileChoice(false);

    if(tmpAxis(1) <= x & x <= tmpAxis(2) ...
       & tmpAxis(3) <= y & y <= tmpAxis(4) ...
       & data(selectIdx).clusterMask(y,x) ~= 0)

      resetPlot();
      showCrossCorrWithOthers(selectIdx, ...
			      data(selectIdx).numberedNeuronMask(y,x));
    end

    set(handles.fig,'WindowButtonDownFcn', @handleEarlyEventSliceClickReturn);

  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function handleEarlyEventSliceClickReturn(source, event)
    
    resetPlot();
    selectIdx = allowMultiFileChoice(false);
    locateEarlyNeurons(selectIdx);

    set(handles.fig,'WindowButtonDownFcn', @handleEarlyEventSliceClick);

  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function showCrossCorrWithOthers(dataIdx,neuronIdx)

    maxDist = 10;
  
    allDiffs = [];

    if(~isempty(data(dataIdx).eventStartIdx{neuronIdx}))
      for j = 1:data(dataIdx).numNeurons
	if(isempty(data(dataIdx).eventStartIdx{j}))
  	  continue
        end

        timeDiff = repmat(data(dataIdx).eventStartIdx{j}, ...
			  1,length(data(dataIdx).eventStartIdx{neuronIdx})) ...
                 - repmat(transpose(data(dataIdx).eventStartIdx{neuronIdx}), ...
			  length(data(dataIdx).eventStartIdx{j}),1);

        idx = find(abs(timeDiff) <= maxDist);

        allDiffs = [allDiffs; timeDiff(idx)];
      end
    end

    edges = -maxDist:maxDist;
    n = histc(allDiffs,edges);

    resetPlot();
    if(~isempty(n))
      bar(edges,n,'histc')
    else
      title('No activity in neuron')
    end
    xlabel('Neuron''s relative onset')
    ylabel('Bin count')

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function showPairFreq(pairDataIdx)

    tmpFreq  = zeros(size(data(pairDataIdx(1)).pairFreq));
    tmpFreqS = zeros(size(data(pairDataIdx(1)).pairFreqShuffle));

    for iD = 1:length(pairDataIdx)
      tmpFreq  = tmpFreq + data(pairDataIdx(iD)).pairFreq;
      tmpFreqS = tmpFreqS + data(pairDataIdx(iD)).pairFreqShuffle;
    end

    p(2) = stairs(detection.distEdges,tmpFreqS,'k--','linewidth',3);
    hold on
    p(1) = stairs(detection.distEdges,tmpFreq,'r-','linewidth',3);
    legend(p, 'Raw data', 'Shuffled')
    xlabel('Distance')
    ylabel('Pair frequency')
    title(sprintf('Pairs within %d frames', detection.pairDt))

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function showCrossCorr(dataIdx)

    tmpCorr = zeros(size(data(dataIdx(1)).crossCorr));
    tmpCorrShuffle = zeros(size(data(dataIdx(1)).shuffleCrossCorr));

    for iD = 1:length(dataIdx)
      tmpCorr = tmpCorr + data(dataIdx(iD)).crossCorr;
      tmpCorrShuffle = tmpCorrShuffle + data(dataIdx(iD)).shuffleCrossCorr;
    end

    % p = bar(detection.CCedges,tmpCorr,'histc');
    p = bar(detection.CCedges ...
	    + (detection.CCedges(2)-detection.CCedges(1))/2,...
	    tmpCorr, ...
	    'facecolor', [1 0 0], 'edgecolor', [1 0 0], ...
	    'barwidth', 0.8);
    hold on;
    %ps = bar(detection.CCedges, tmpCorrShuffle,'histc');
    ps = bar(detection.CCedges ...
	     + (detection.CCedges(2)-detection.CCedges(1))/2, ...
	     tmpCorrShuffle, ...
	     'facecolor', [0 0 0], 'edgecolor', [0 0 0], ...
	     'barwidth', 0.5);

    legend([p ps], 'Raw data', 'Shuffled')

    xlabel('Time difference (frames)')
    ylabel('Bin count')
    axis tight

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function showFrequencyHistogram(dataIdx)

    maxFreq = 0;

    for iD = 1:length(dataIdx)
      maxFreq = max(maxFreq,max(data(dataIdx(iD)).eventFreq));
    end

    edges = 0:0.005:max(0.2,maxFreq);
    n = zeros(length(edges),length(dataIdx));

    for iD = 1:length(dataIdx)
      n(:,iD) = histc(data(dataIdx(iD)).eventFreq,edges);
    end

    meanN = mean(n,2);
    stdN = std(n,0,2);

    if(length(dataIdx) > 1)
      errorbar(edges,meanN,stdN,'.');
      hold on
    end

    bar(edges,meanN);
    a = axis; a(1) = 0 - edges(2); a(2) = max(edges); axis(a);

    xlabel('Frequency (Hz)')
    ylabel('Count')

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function plotPiaDistFreq(dataIdx)
    for i = 1:length(dataIdx)
      plot(data(dataIdx).piaDist,data(dataIdx).eventFreq, ...
	   'k.', 'markersize',20)
      hold on
    end

    hold off
    xlabel('Distance from pia (micrometers)')
    ylabel('Firing frequency (Hz)')

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function plotAmplitudeHistogram(selectIdx,filter)

    allAmps = [];

    for i = 1:length(selectIdx)

      idx = [];
 
      switch(filter)
        case 0 % No filter, use all amplitudes
          idx = 1:data(selectIdx(i)).numNeurons;
        case 1 % Only do clustered neurons
          if(~isempty(data(selectIdx(i)).neuronClusters))
	    idx = data(selectIdx(i)).neuronClusters{1};
          else
            % No cluster
            idx = [];
          end
      end

      for j = 1:length(idx)
        % Amplitude is 1 - peak value
	% allAmps = [allAmps; 1 - data(selectIdx(i)).eventPeakValue{idx(j)}];

        % Redefined to be peak value - value at start of event
	minPeak = data(selectIdx(i)).eventPeakValue{idx(j)};
        startFrame = data(selectIdx(i)).eventStartIdx{idx(j)};
        startVal = data(selectIdx(i)).relTrace(startFrame,idx(j));

        if(~isempty(minPeak))
          allAmps = [allAmps; startVal-minPeak];         
        end

      end

    end

    edges = 0:0.01:1;
    n = histc(allAmps,edges);
    bar(edges,n,'histc');
    xlabel('Relative amplitude')
    ylabel('Bin count')

    a = axis; a(1) = 0; a(2) = 1; axis(a);

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function plotISIHistogram(selectIdx,filter)

    allISI = [];

    for i = 1:length(selectIdx)

      idx = [];
 
      switch(filter)
        case 0 % No filter, use all amplitudes
          idx = 1:data(selectIdx(i)).numNeurons;
        case 1 % Only do clustered neurons
          if(~isempty(data(selectIdx(i)).neuronClusters))
	    idx = data(selectIdx(i)).neuronClusters{1};
          else
            % No cluster
            idx = [];
          end
      end

      for j = 1:length(idx)
	ISI = diff(data(selectIdx(i)).eventStartIdx{idx(j)}) ...
	      / data(selectIdx(i)).freq;
	allISI = [allISI; ISI];
      end

    end

    edges = 0:1:max(allISI(:));
    n = histc(allISI,edges);
    bar(edges,n,'histc');
    xlabel('ISI (s)')
    ylabel('Bin count')

    a = axis; a(1) = 0; a(2) = edges(end); axis(a);

  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function plotAreaHistogram(selectIdx,filter)

    allAreas = [];

    for i = 1:length(selectIdx)

      idx = [];
 
      switch(filter)
        case 0 % No filter, use all amplitudes
          idx = 1:data(selectIdx(i)).numNeurons;
        case 1 % Only do clustered neurons
          if(~isempty(data(selectIdx(i)).neuronClusters))
	    idx = data(selectIdx(i)).neuronClusters{1};
          else
            % No cluster
            idx = [];
          end
      end

      for j = 1:length(idx)
	allAreas = [allAreas; data(selectIdx(i)).eventArea{idx(j)}];
      end

    end

    edges = 0:1:max(allAreas(:));
    n = histc(allAreas,edges);
    bar(edges,n,'histc');
    xlabel('Relative area')
    ylabel('Bin count')

    a = axis; a(1) = 0; a(2) = edges(end); axis(a);

  end


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function plotCorrMatrix(selectIdx)
   try
    neuronIdx = setdiff(1:data(selectIdx).numNeurons, ...
			data(selectIdx).specialIdx);

    corrMat = corrcoef(data(selectIdx).relTrace(:,neuronIdx));

    cidx = find(ismember(neuronIdx,data(selectIdx).neuronClusters{1}));
    ridx = setdiff(1:length(neuronIdx),cidx);
    idx = [cidx,ridx];

    imshow(corrMat(idx,idx)), colorbar

   catch e
    getReport(e)
    keyboard
   end

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function plotCorrDistribution(selectIdx)

    neuronIdx = setdiff(1:data(selectIdx).numNeurons, ...
			data(selectIdx).specialIdx);

    corrMat = corrcoef(data(selectIdx).relTrace(:,neuronIdx));

    % We want to exclude the diagonal, and only take the lower part of matrix
    hist(corrMat(find(~triu(ones(size(corrMat))))),20);
    xlabel('Correlation')

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function updateGUI(selIdx)
    set(handles.plot, 'Visible', 'on');

    if(~exist('selIdx'))
      selIdx = 1:length(data);
    end

    set(handles.selectData, 'String', strvcat(data(:).dataName), ...
 	                    'Min', 1, 'Max', 1000, ...
 	                    'Value', selIdx);

  end

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function displayInfo()
 
    if(isempty(data))
      return
    end

    % Check which trace(s) user watches
    selectIdx = get(handles.selectData,'Value');

    switch(length(selectIdx))
      case 0
	set(handles.info, 'String', 'No data selected')
      case 1
        normalIdx = setdiff(1:data(selectIdx).numNeurons,data(selectIdx).specialIdx);

        meanFreqAll = mean(data(selectIdx).eventFreq(normalIdx));
        stdFreqAll = std(data(selectIdx).eventFreq(normalIdx));

        idxActive = intersect(find(data(selectIdx).eventFreq > 0),normalIdx);
        meanFreqActive = mean(data(selectIdx).eventFreq(idxActive));
        stdFreqActive = std(data(selectIdx).eventFreq(idxActive));

        % Now special cells do not count towards frequency...

        numActive = nnz(data(selectIdx).eventFreq(normalIdx));
        numSilent = nnz(data(selectIdx).eventFreq(normalIdx) == 0);
        numSpecial = data(selectIdx).numSpecial;
        numExcluded = data(selectIdx).numExcluded;

        if(~isempty(data(selectIdx).neuronClusters))
          % Number of neurons in cluster
          neuronIdx = data(selectIdx).neuronClusters{1};
          numCluster = length(neuronIdx);

          meanFreqCluster = mean(data(selectIdx).eventFreq(neuronIdx));
          stdFreqCluster = std(data(selectIdx).eventFreq(neuronIdx));

        else
          numCluster = NaN;
          meanFreqCluster = NaN;
          stdFreqCluster = NaN;
        end

	meta = data(selectIdx).meta;

	set(handles.info, 'String', ...
	    sprintf(['Non-special (%d): %.3f +/- %.3f Hz\n', ...
		     'Active (%d): %.3f +/- %.3f Hz\n', ...
		     'Cluster (%d): %.3f +/- %.3f Hz\n', ...
	  	     'Silent (%d)\n', ...
		     'Special (%d), Excluded (%d)\n', ...
                     'P%d,%s,%s,%s,%d/%d\n' ...
		     'Weight: %d'], ...
		    numActive+numSilent, meanFreqAll, stdFreqAll, ...
		    numActive, meanFreqActive, stdFreqActive, ...
		    numCluster, meanFreqCluster, stdFreqCluster, ...
		    numSilent, numSpecial, numExcluded, ...
		    meta.age,meta.condition,meta.genotype, ...
		    meta.hemisphere, meta.sliceNumber, meta.totalSlices, ...
		    meta.weight));

      otherwise
 	set(handles.info, 'String', ...
	    'Multi data-set info will be implemented later.')

    end
	      

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

      set(handles.fig,'CurrentAxes',handles.plot)
      imshow(logoImg);

    catch exception
      disp(getReport(exception))

      % We end up here in case something failed above
      disp('Unable to load photo from webserver.')

      cachedPics = dir('pics/logo*jpg');

      % If there are cached pictures, choose one of them at random
      if(~isempty(cachedPics))
        idx = randperm(length(cachedPics));
        logoImg = imread(['pics/' cachedPics(idx(1)).name]);

        set(handles.fig,'CurrentAxes',handles.plot)
        imshow(logoImg);
      end
    end

  end


%%%%%%%%%%%%

  showPhoto();

  if(rand(1) < 0.02)
    music = load('handel');
    sound(music.y,music.Fs);
  end

  %disp('Type return')
  % keyboard

end
