function piezo_call_struct = inspect_piezo_recordings(base_dir)

logger_dirs = dir([base_dir 'piezo_data' filesep 'logger*']);
nLogger = length(logger_dirs);
logger_sampling_period_usec = 20;
piezo_fs = 1/(1e-6*logger_sampling_period_usec);
audio_fs = 250e3;
logger_num_to_align_to = 3;
logger_idx_to_align_to = find(arrayfun(@(x) ~isempty(strfind(x.name,num2str(logger_num_to_align_to))),logger_dirs));
logger_idx_to_align = setdiff(1:nLogger,logger_idx_to_align_to);
audio_dir = fullfile(base_dir, 'audio', 'ch1');

s = load(fullfile(audio_dir, 'cut_call_data.mat'));
cut_call_data = s.cut_call_data;
cut_call_data = cut_call_data(~[cut_call_data.noise]);

piezo2piezo = load([logger_dirs(logger_idx_to_align).folder filesep logger_dirs(logger_idx_to_align).name filesep 'piezo2piezo_fit.mat']);
audio2piezo = load([audio_dir 'audio2piezo_fit.mat']);

timestamps = cell(1,nLogger);
piezo_mean_values = zeros(1,nLogger);
piezo_data = cell(1,nLogger);

for logger_k = 1:nLogger
    tsData = load([logger_dirs(logger_k).folder filesep logger_dirs(logger_k).name filesep 'CSC0.mat']);
    timestamps_usec = get_timestamps_for_Nlg_voltage_all_samples(length(tsData.AD_count_int16),tsData.indices_of_first_samples,tsData.timestamps_of_first_samples_usec,logger_sampling_period_usec);
    piezo_data{logger_k} = double(tsData.AD_count_int16);
    piezo_mean_values(logger_k) = mean(piezo_data{logger_k});
    if logger_k == logger_idx_to_align_to
        timestamps{logger_k} = (1e-3*timestamps_usec) - piezo2piezo.first_piezo_pulse_time(1);
    else
        timestamps{logger_k} = piezo2piezo_time(piezo2piezo,1e-3*timestamps_usec);
    end
    clear tsData
end
clear timestamps_usec

%%

call_offset = 0.1; % seconds
call_offset_samples = audio_fs*call_offset;

all_wav_files = dir([audio_dir '*.WAV']);
wav_file_names = {all_wav_files(:).name};
wav_file_nums = cellfun(@(x) str2double(x(end-10:end-4)),wav_file_names);
[~,idx] = sort(wav_file_nums);
all_wav_files = all_wav_files(idx);
wav_file_names = wav_file_names(idx);

nCall = length(cut_call_data);
piezo_call_data = cell(1,nCall);
wav_call_data = cell(1,nCall);
for call_k = 1:nCall
    
    wavFiles = unique({cut_call_data(call_k).fName});
    n_wav_files = length(wavFiles);
    wav_files_idx = zeros(1,n_wav_files);
    
    for wav_k = 1:n_wav_files
        [~,fName,ext] = fileparts(wavFiles{wav_k});
        wav_files_idx(wav_k) = find(strcmpi([fName ext],wav_file_names));
    end
    
    call_end_offset = [0 audio2piezo.total_samples_by_file(wav_files_idx)];
    call_end_offset = sum(call_end_offset(1:n_wav_files));
    
    if cut_call_data(call_k(1)).callpos(1)-call_offset_samples < 0
        wav_files_idx = [wav_files_idx(1)-1 wav_files_idx];
        call_start_offset = audio2piezo.total_samples_by_file(wav_files_idx(1));
    else
        call_start_offset = 0;
    end
    
    if cut_call_data(call_k(end)).callpos(2)+call_offset_samples > audio2piezo.total_samples_by_file(wav_files_idx(end))
        wav_files_idx = [wav_files_idx wav_files_idx(end)+1 ];
        n_wav_files = n_wav_files + 1;
    end
    
    wavData = cell(1,n_wav_files);
    for wav_k = 1:n_wav_files
        wavData{wav_k} = audioread([audio_dir all_wav_files(wav_files_idx(wav_k)).name]);
    end
    wavData = vertcat(wavData{:});
    
    wav_chunk_idx = (call_start_offset + cut_call_data(call_k(1)).callpos(1) - call_offset_samples):(call_end_offset + cut_call_data(call_k(end)).callpos(2) + call_offset_samples);
    wav_call_data{call_k} = wavData(wav_chunk_idx);
    
    piezo_call_data{call_k} = cell(1,nLogger);
    for logger_k = 1:nLogger
        [~,call_start_idx] = min(abs(cut_call_data(call_k(1)).corrected_callpos(1) - timestamps{logger_k}));
        [~,call_end_idx] = min(abs(cut_call_data(call_k(end)).corrected_callpos(2) - timestamps{logger_k}));
        piezo_call_data{call_k}{logger_k} = piezo_data{logger_k}(call_start_idx-(piezo_fs*call_offset):call_end_idx+(piezo_fs*call_offset)) - piezo_mean_values(logger_k);
    end
end

piezo_call_struct = struct('piezo_call_data',piezo_call_data,'wav_call_data',wav_call_data);
if isfield(cut_call_data,'callID')
    [piezo_call_struct.callID] = cut_call_data.callID;
else
    callID = num2cell(1:length(cut_call_data));
    [piezo_call_struct.callID] = callID{:};
end

end