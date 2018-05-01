function [shared_piezo_pulse_times, first_piezo_pulse_time] = align_piezo_to_piezo(base_dir,ttl_pulse_dt,logger_nums,session_strings)
%%
% Function to correct for clock drift between streampix video recordings and
% piezoelectric audio recordings.
%
% INPUT:
% base_dir: base directory of experiment. This script expects this
% directory to contain the subfolders 'video\Camera #\' and 'piezo_data\'.
%
% ttl_pulse_dt,corr_pulse_err,correct_end_off,correct_loop: see help for
% ttl_times2pulses.m
%
% wav_file_nums: vector of integers correspoding to .WAV file numbers to
% analyze.
%
% session_strings: cell of strings used to demarcate start and stop of
% time period to analyze in this script from EVENTLOG file.
%
% OUTPUT:
%
% shared_piezo_pulse_times: times (ms) in piezo time when TTL pulses arrived on
% the piezo Tx. To be used with video2piezo_time to locally interpolate
% differences between time on streampix and piezo and correct for those
% differences.
%
% shared_video_pulse_times: times (ms) in streampix time when TTL pulses arrived 
% on streampix. To be used with video2piezo_time to locally interpolate
% differences between time on video and piezo and correct for those
% differences.
%
%
% first_piezo_pulse_time: time (ms, in piezo time) when the first TTL pulse train
% that is used for synchronization arrived. Used to align video and piezo
% times before scaling by estimated clock differences.
%
% first_video_pulse_time: time (ms, in video time) when the first TTL pulse train
% that is used for synchronization arrived. Used to align video and piezo
% times before scaling by estimated clock differences.

corr_pulse_err = true;
correct_end_off = true;
correct_loop = true;

save_options_parameters_CD_figure = 1;
%%%

piezo_pulse = cell(1,length(logger_nums));
piezo_pulse_times = cell(1,length(logger_nums));

for n = 1:length(logger_nums)
    
    eventfile = [base_dir 'piezo_data' filesep 'logger' num2str(logger_nums(n)) filesep 'EVENTS.mat']; % load file with TTL status info
    load(eventfile);
    
    session_start_and_end = zeros(1,2);
    start_end = {'start','end'};
    
    for s = 1:2
        session_string_pos = find(cellfun(@(x) ~isempty(strfind(x,session_strings{s})),event_types_and_details));
        if numel(session_string_pos) ~= 1
            if numel(session_string_pos) > 1
                display(['more than one session ' start_end{s} ' string in event file, choose index of events to use as session ' start_end{s}]);
            elseif numel(session_string_pos) == 0
                display(['couldn''t find session ' start_end{s} ' string in event file, choose index of events to use as session ' start_end{s}]);
            end
        session_string_pos_old =session_string_pos;
        keyboard;
        session_string_pos = input(sprintf('input index for %s into variable event_types_and_details, choose from %d %d %d %d %d %d', start_end{s}, session_string_pos_old));
        end
        session_start_and_end(s) = event_timestamps_usec(session_string_pos);
    end
    
    % extract only relevant TTL status changes
    event_types_and_details = event_types_and_details((event_timestamps_usec >= session_start_and_end(1)) & (event_timestamps_usec <= session_start_and_end(2)));
    event_timestamps_usec = event_timestamps_usec((event_timestamps_usec >= session_start_and_end(1)) & (event_timestamps_usec <= session_start_and_end(2)));
    
    din = cellfun(@(x) contains(x,'Digital in'),event_types_and_details); % extract which lines in EVENTS correspond to TTL status changes
    nlg_time_din = 1e-3*event_timestamps_usec(din)'; % find times (ms) when TTL status changes
    [piezo_pulse{n}, piezo_pulse_times{n}] = ttl_times2pulses(nlg_time_din,ttl_pulse_dt,corr_pulse_err,correct_end_off,correct_loop); % extract TTL pulses and time
end

%% synchronize piezo --> piezo
if length(unique(piezo_pulse{1}))/length(piezo_pulse{1}) ~= 1 || length(unique(piezo_pulse{2}))/length(piezo_pulse{2}) ~= 1 
    display('repeated pulses!');
    keyboard;
end
shared_pulse_piezo_idx = cell(1,2);
[~, shared_pulse_piezo_idx{1}, shared_pulse_piezo_idx{2}] = intersect(piezo_pulse{1},piezo_pulse{2}); % determine which pulses are on both the NLG and video recordings

% extract only shared pulses
shared_piezo_pulse_times = {piezo_pulse_times{1}(shared_pulse_piezo_idx{1}),piezo_pulse_times{2}(shared_pulse_piezo_idx{2})};

first_piezo_pulse_time = [shared_piezo_pulse_times{1}(1) shared_piezo_pulse_times{2}(1)];

clock_differences_at_pulses = (shared_piezo_pulse_times{1} - first_piezo_pulse_time(1)) - (shared_piezo_pulse_times{2} - first_piezo_pulse_time(2)); % determine difference between piezo loggers' timestamps when pulses arrived

figure
hold on
plot((shared_piezo_pulse_times{1} - first_piezo_pulse_time(1)),clock_differences_at_pulses,'.-');
xlabel('Incoming Piezo Pulse Times')
ylabel('Difference between piezo 1 clock and piezo 2 clock');
legend('real clock difference');

if save_options_parameters_CD_figure
    saveas(gcf,[base_dir 'piezo_data' filesep 'logger' num2str(logger_nums(end)) filesep 'CD_correction_video_piezo.fig'])
end
end