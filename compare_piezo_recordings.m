spec_win_params_s = [1e-3 1.75e-3];
audio_fs = 250e3;
piezo_fs = 50e3;
spec_win_params_audio = round(spec_win_params_s*audio_fs);
spec_win_params_piezo = round(spec_win_params_s*piezo_fs);
nfft_audio = 2^12;
nfft_piezo = 2^10;
nLogger = 2;
call_offset = 0.1;
max_lag = 10e-3;
call_offset_audio = call_offset*audio_fs;
call_offset_piezo = call_offset*piezo_fs;

freq_bands = [0 4; 6 10] * 1e3;
[b_lp,a_lp] = butter(4,2e3/(piezo_fs/2),'low');
downsample_factor = audio_fs/piezo_fs;
smooth_span = spec_win_params_piezo(1)*10;
r = zeros(length(piezo_call_struct),nLogger);
d = zeros(length(piezo_call_struct),nLogger);
sample_diffs = zeros(length(piezo_call_struct),nLogger);
call_rms = zeros(1,length(piezo_call_struct));
call_length = zeros(1,length(piezo_call_struct));
piezo_power_ratio = zeros(length(piezo_call_struct),nLogger);
for call_k = 1:length(piezo_call_struct)
    
    audio_data = piezo_call_struct(call_k).wav_call_data(call_offset_audio:end-call_offset_audio);
    call_rms(call_k) = rms(audio_data);
    call_length(call_k) = length(audio_data)/audio_fs;
    audio_data_ds = downsample(audio_data,5);
    audio_data_envelope = zscore(envelope(audio_data_ds,spec_win_params_piezo(1),'rms'));
    
   
    for k = 1:nLogger
        
        piezo_data = piezo_call_struct(call_k).piezo_call_data{k}(call_offset_piezo:end-call_offset_piezo);
        piezo_data_filt = filtfilt(b_lp,a_lp,piezo_data);
        
        piezo_power_ratio(call_k,k) = bandpower(piezo_data,piezo_fs,freq_bands(1,:))/bandpower(piezo_data,piezo_fs,freq_bands(2,:));
        
        piezo_data_envelope = zscore(envelope(piezo_data_filt,spec_win_params_piezo(1),'rms')');
        r(call_k,k) = max(xcorr(piezo_data_envelope,audio_data_envelope,round(max_lag*piezo_fs)));
        
    end
    
end