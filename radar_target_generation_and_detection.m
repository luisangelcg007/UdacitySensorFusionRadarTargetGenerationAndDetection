clear all
clc;

%% Radar Specifications 
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Frequency of operation = 77GHz
% Max Range = 200m
% Range Resolution = 1 m
% Max Velocity = 100 m/s
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%speed of light = 3e8

radarMaxRange = 200;
radarRangeResolution = 1;
radarMaxVelocity = 100;
speedOfLight = 3e8;
%% User Defined Range and Velocity of target
% *%TODO* :
% define the target's initial position and velocity. Note : Velocity
% remains contant

targetRange = 110;
targetVelocity = -20;


%% FMCW Waveform Generation

% *%TODO* :
%Design the FMCW waveform by giving the specs of each of its parameters.
% Calculate the Bandwidth (B), Chirp Time (Tchirp) and Slope (slope) of the FMCW
% chirp using the requirements above.
bandwidth = speedOfLight / (2 * radarRangeResolution);
Tchirp = 5.5 * 2 * radarMaxRange / speedOfLight;
slope = bandwidth / Tchirp;

%Operating carrier frequency of Radar 
fc= 77e9;             %carrier freq

                                                          
%The number of chirps in one sequence. Its ideal to have 2^ value for the ease of running the FFT
%for Doppler Estimation. 
Nd=128;                   % #of doppler cells OR #of sent periods % number of chirps

%The number of samples on each chirp. 
Nr=1024;                  %for length of time OR # of range cells

% Timestamp for running the displacement scenario for every sample on each
% chirp
t=linspace(0,Nd*Tchirp,Nr*Nd); %total time for samples


%Creating the vectors for Tx, Rx and Mix based on the total samples input.
Tx=zeros(1,length(t)); %transmitted signal
Rx=zeros(1,length(t)); %received signal
Mix = zeros(1,length(t)); %beat signal

%Similar vectors for range_covered and time delay.
r_t=zeros(1,length(t));
td=zeros(1,length(t));


%% Signal generation and Moving Target simulation
% Running the radar scenario over the time. 

for i=1:length(t)         
    
    
    % *%TODO* :
    %For each time stamp update the Range of the Target for constant velocity.
    r_t(i) = targetRange + targetVelocity * t(i);
    td(i) = 2 * r_t(i) / speedOfLight;
    
    % *%TODO* :
    %For each time sample we need update the transmitted and
    %received signal. 
    Tx(i) = cos(2 * pi * (fc * t(i) +((slope * t(i)^2)/2)));
    Rx(i)  = cos(2 * pi * (fc * (t(i) - td(i)) + ((slope * (t(i) - td(i))^2)/2)));
    
    % *%TODO* :
    %Now by mixing the Transmit and Receive generate the beat signal
    %This is done by element wise matrix multiplication of Transmit and
    %Receiver Signal
    Mix(i) = Tx(i) .* Rx(i);
    
end

%% RANGE MEASUREMENT


 % *%TODO* :
%reshape the vector into Nr*Nd array. Nr and Nd here would also define the size of
%Range and Doppler FFT respectively.
Mix = reshape(Mix, [Nr, Nd]);

 % *%TODO* :
%run the FFT on the beat signal along the range bins dimension (Nr) and
%normalize.
signalFFT = fft(Mix, Nr);
signalFFT = signalFFT ./ Nr;

 % *%TODO* :
% Take the absolute value of FFT output
signalFFT = abs(signalFFT);

 % *%TODO* :
% Output of FFT is double sided signal, but we are interested in only one side of the spectrum.
% Hence we throw out half of the samples.
halfSignalFFT = signalFFT(1:Nr/2);

%plotting the range
figure ('Name','Range from First FFT')
subplot(2,1,1)

 % *%TODO* :
 % plot FFT output 
plot(halfSignalFFT);
 
axis ([0 200 0 1]);



%% RANGE DOPPLER RESPONSE
% The 2D FFT implementation is already provided here. This will run a 2DFFT
% on the mixed signal (beat signal) output and generate a range doppler
% map.You will implement CFAR on the generated RDM


% Range Doppler Map Generation.

% The output of the 2D FFT is an image that has reponse in the range and
% doppler FFT bins. So, it is important to convert the axis from bin sizes
% to range and doppler based on their Max values.

Mix=reshape(Mix,[Nr,Nd]);

% 2D FFT using the FFT size for both dimensions.
sig_fft2 = fft2(Mix,Nr,Nd);

% Taking just one side of signal from Range dimension.
sig_fft2 = sig_fft2(1:Nr/2,1:Nd);
sig_fft2 = fftshift (sig_fft2);
RDM = abs(sig_fft2);
RDM = 10*log10(RDM) ;

%use the surf function to plot the output of 2DFFT and to show axis in both
%dimensions
doppler_axis = linspace(-100,100,Nd);
range_axis = linspace(-200,200,Nr/2)*((Nr/2)/400);
figure,surf(doppler_axis,range_axis,RDM);

%% CFAR implementation

%Slide Window through the complete Range Doppler Map

% *%TODO* :
%Select the number of Training Cells in both the dimensions.
trainCells = 10;
trainBand = 8;

% *%TODO* :
%Select the number of Guard Cells in both dimensions around the Cell under 
%test (CUT) for accurate estimation
guardCells = 4;
guardBand = 4;

% *%TODO* :
% offset the threshold by SNR value in dB
offset = 1.4;

% *%TODO* :
%Create a vector to store noise_level for each iteration on training cells
noise_level = zeros(1,1);

% *%TODO* :
%design a loop such that it slides the CUT across range doppler map by
%giving margins at the edges for Training and Guard Cells.
%For every iteration sum the signal level within all the training
%cells. To sum convert the value from logarithmic to linear using db2pow
%function. Average the summed values for all of the training
%cells used. After averaging convert it back to logarithimic using pow2db.
%Further add the offset to it to determine the threshold. Next, compare the
%signal under CUT with this threshold. If the CUT level > threshold assign
%it a value of 1, else equate it to 0.


   % Use RDM[x,y] as the matrix from the output of 2D FFT for implementing
   % CFAR
   
dopplerMap = RDM / max(RDM(:));

row1InitVal = trainCells + guardCells + 1;
row1EndVal = (Nr/2) - (trainCells + guardCells);
col1InitVal = trainBand + guardBand + 1;
col1EndVal = (Nd) - (trainBand + guardBand);

for row1 = row1InitVal : row1EndVal
  for col1 = col1InitVal : col1EndVal
    %Create a vector to store noise_level for each iteration on training cells
    noise = noise_level;

    for row2 = row1 - (trainCells + guardCells) : row1 + (trainCells + guardCells)
      for col2 = col1 - (trainBand + guardBand) : col1 + (trainBand + guardBand)
          
          absoluteValueRowDifference = abs(row1 - row2);
          absoluteValueColumnDifference = abs(col1 - col2);
          
        if (absoluteValueRowDifference > guardCells || absoluteValueColumnDifference > guardBand)
          noise = noise + db2pow(dopplerMap(row2, col2));
        end
        
      end
    end

    % Calculate threshold from noise average then add the offset
    threshold = pow2db(noise / (2 * (trainBand + guardBand + 1) * 2 * (trainCells + guardCells + 1) - (guardCells * guardBand) - 1));
    threshold = threshold + offset;

    cellUnderTest = dopplerMap(row1,col1);

    if (cellUnderTest > threshold)
      dopplerMap(row1, col1) = 1;
    else
      dopplerMap(row1, col1) = 0;
    end
    
  end
end

% *%TODO* :
% The process above will generate a thresholded block, which is smaller 
%than the Range Doppler Map as the CUT cannot be located at the edges of
%matrix. Hence,few cells will not be thresholded. To keep the map size same
% set those values to 0. 
dopplerMap(dopplerMap~=0 & dopplerMap~=1) = 0;

% *%TODO* :
%display the CFAR output using the Surf function like we did for Range
%Doppler Response output.
figure('Name', 'CA-CFAR Filtered RDM')
surf(doppler_axis,range_axis,dopplerMap);
colorbar;
 