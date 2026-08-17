function [results, figures] = StochasticExperiment(varargin)
%STOCHASTICEXPERIMENT Run and plot the Poisson stochastic study.
%
%   [RESULTS,FIGURES] = STOCHASTICEXPERIMENT() runs the stochastic study
%   for FlatSBP, HSBP, and DTHSBP at swarm sizes 1000:1000:5000 and
%   generates the stochastic figures.
%
%   Optional name-value arguments:
%       'Protocols'    - protocol string array
%       'SwarmSizes'   - numeric vector
%       'Repetitions'  - number of independent repetitions
%       'BaseSeed'     - base random seed
%
%   This driver uses the stochastic experiment configuration already
%   defined by config.m, including the configured simulation horizon and
%   Poisson Join/Leave/Failure rates. It does not modify configuration.

    p = inputParser;
    addParameter(p,'Protocols',["FlatSBP","HSBP","DTHSBP"]);
    addParameter(p,'SwarmSizes',[1000 2000 3000 4000 5000]);
    addParameter(p,'Repetitions',10,@(x) isnumeric(x) && isscalar(x) && x >= 1 && x == floor(x));
    addParameter(p,'BaseSeed',42,@(x) isnumeric(x) && isscalar(x));
    parse(p,varargin{:});

    protocols = string(p.Results.Protocols);
    swarmSizes = p.Results.SwarmSizes;
    repetitions = p.Results.Repetitions;
    baseSeed = p.Results.BaseSeed;

    fprintf('============================================\n');
    fprintf('Stochastic Experiment\n');
    fprintf('============================================\n');
    fprintf('Protocols    : %s\n',strjoin(protocols,', '));
    fprintf('Swarm sizes  : %s\n',mat2str(swarmSizes));
    fprintf('Repetitions  : %d\n',repetitions);
    fprintf('Base seed    : %g\n',baseSeed);
    fprintf('============================================\n');

    results = runStochasticStudy(protocols,swarmSizes,repetitions,baseSeed);

    if isempty(results)
        error('StochasticExperiment:NoResults', ...
            'The stochastic study returned no results.');
    end

    success = [results.success];
    if ~all(success)
        failed = find(~success);
        error('StochasticExperiment:RunFailure', ...
            '%d stochastic runs failed. First failed result index: %d.', ...
            numel(failed),failed(1));
    end

    fprintf('Successful runs: %d / %d\n',numel(results),numel(results));
    fprintf('Generating stochastic figures...\n');

    figures = plotStochasticFigures(results);

    fprintf('Figures generated: %d\n',numel(figures));
    fprintf('============================================\n');
    fprintf('STOCHASTIC EXPERIMENT COMPLETE\n');
    fprintf('============================================\n');
end
