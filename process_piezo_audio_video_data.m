function process_piezo_audio_video_data
audio_fs = 250e3;
piezo_fs = 50e3;
inter_ttl_duration = 4e3;
%base_dir = 'C:\Users\phyllo\Documents\Maimon\misc\piezo_testing\audioLogger_testing\03212018\';
base_dir = '/Volumes/JulieBatsDrive/04272018/';
logger_dirs = dir(fullfile(base_dir, 'audio_logger_format', 'logger*'));
nLogger = length(logger_dirs);
input_dir = cell(1,nLogger);
output_dir = cell(1,nLogger);
logger_num_to_align_to = 3;
logger_nums = [3 6];

for logger_k = 1:nLogger
    input_dir{logger_k} = [logger_dirs(logger_k).folder filesep logger_dirs(logger_k).name filesep];
    output_dir{logger_k} = [base_dir 'piezo_data' filesep logger_dirs(logger_k).name filesep];
end
audio_dir = fullfile(base_dir, 'audio','ch1');
video_dirs = {[base_dir 'video' filesep 'Camera 1' filesep], [base_dir 'video' filesep 'Camera 2' filesep]};

session_strings = {'start_communication','end_communication'};
wav_files_struct = dir(fullfile(base_dir, 'audio', 'ch1','*.WAV'));
wav_file_names = {wav_files_struct(:).name};
wav_file_nums = cellfun(@(x) str2double(x(end-10:end-4)),wav_file_names);

for logger_k = 1:nLogger
    extract_audioLogger_data(input_dir{logger_k},output_dir{logger_k});
end


[shared_piezo_pulse_times, shared_audio_pulse_times, total_samples_by_file, first_piezo_pulse_time, first_audio_pulse_time] = align_avi_to_piezo(base_dir,inter_ttl_duration,logger_num_to_align_to,wav_file_nums,session_strings);
save([audio_dir 'audio2piezo_fit'],'shared_piezo_pulse_times', 'shared_audio_pulse_times', 'first_piezo_pulse_time', 'first_audio_pulse_time','total_samples_by_file');
findcalls_v5_mcr(audio_dir,250e3,'wav');
manual_classify_calls(audio_dir,'Call');

cut_call_data = get_corrected_call_times_piezo(audio_dir,[audio_dir 'Analyzed_auto\'],'Call');
save([audio_dir 'cut_call_data.mat'],'cut_call_data');

for v = 1:2
    [shared_piezo_pulse_times, shared_video_pulse_times, first_piezo_pulse_time, first_video_pulse_time] = align_video_to_piezo(base_dir,v,inter_ttl_duration,logger_num_to_align_to,session_strings);
    save([video_dirs{v} 'video2piezo_fit'],'shared_piezo_pulse_times', 'shared_video_pulse_times', 'first_piezo_pulse_time', 'first_video_pulse_time');
    
    frame_ts_info = build_video_timestamps(video_dirs{v},'piezo');
    save([video_dirs{v} 'frame_timestamps_info.mat'],'frame_ts_info');
end

[shared_piezo_pulse_times, first_piezo_pulse_time] = align_piezo_to_piezo(base_dir,inter_ttl_duration,logger_nums,session_strings);
save([output_dir{2} 'piezo2piezo_fit.mat'],'shared_piezo_pulse_times', 'first_piezo_pulse_time');

end