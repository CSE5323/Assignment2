#import "ModuleBViewController.h"
#import "Novocaine.h"
#import "CircularBuffer.h"
#import "SMUGraphHelper.h"
#import "FFTHelper.h"

#define BUFFER_SIZE 2048 * 4
#define RANGE_OF_AVERAGE 25

@interface ModuleBViewController ()
@property (strong, nonatomic) Novocaine *audioManager;
@property (strong, nonatomic) CircularBuffer *buffer;
@property (strong, nonatomic) SMUGraphHelper *graphHelper;
@property (strong, nonatomic) FFTHelper *fftHelper;

@property (weak, nonatomic) IBOutlet UILabel *sliderLabel;
@property (weak, nonatomic) IBOutlet UISlider *frequencySlider;
@property (weak, nonatomic) IBOutlet UILabel *directionLabel;
@property double frequency;
@property BOOL calibrateFlag;
@property float *fftMagnitude;
@property double baselineLeftAverage;
@property double baselineRightAverage;
@end

@implementation ModuleBViewController

#pragma mark Lazy Instantiation
-(Novocaine*)audioManager{
    if(!_audioManager){
        _audioManager = [Novocaine audioManager];
    }
    return _audioManager;
}


-(CircularBuffer*)buffer{
    if(!_buffer){
        _buffer = [[CircularBuffer alloc]initWithNumChannels:1 andBufferSize:BUFFER_SIZE];
    }
    return _buffer;
}

-(SMUGraphHelper*)graphHelper{
    if(!_graphHelper){
        _graphHelper = [[SMUGraphHelper alloc]initWithController:self
                                        preferredFramesPerSecond:15
                                                       numGraphs:3
                                                       plotStyle:PlotStyleSeparated
                                               maxPointsPerGraph:BUFFER_SIZE];
    }
    return _graphHelper;
}

-(FFTHelper*)fftHelper{
    if(!_fftHelper){
        _fftHelper = [[FFTHelper alloc]initWithFFTSize:BUFFER_SIZE];
    }
    
    return _fftHelper;
}


#pragma mark VC Life Cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    //[self setPauseOnWillResignActive:false];
    [self.graphHelper setScreenBoundsBottomHalf];
    
    __block ModuleBViewController * __weak  weakSelf = self;
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels){
        [weakSelf.buffer addNewFloatData:data withNumSamples:numFrames];
    }];
    
    self.frequency = (double)self.frequencySlider.value;
    self.sliderLabel.text = [NSString stringWithFormat:@"%0.0f Hz", self.frequencySlider.value];
    self.frequencySlider.continuous = NO;
    
    self.calibrateFlag = NO;
    
    self.baselineLeftAverage = 0;
    self.baselineRightAverage = 0;
    
    [self.audioManager play];
    float* arrayData = malloc(sizeof(float)*BUFFER_SIZE);
    
    [self.buffer fetchFreshData:arrayData withNumSamples:BUFFER_SIZE];
}

-(void)viewDidDisappear:(BOOL)animated{
    
    [self.audioManager pause];
    [super viewDidDisappear:animated];
}

#pragma mark GLK Inherited Functions
//  override the GLKViewController update function, from OpenGLES
- (void)update{
    // just plot the audio stream
    
    // get audio stream data
    float* arrayData = malloc(sizeof(float)*BUFFER_SIZE);
    _fftMagnitude = malloc(sizeof(float)*BUFFER_SIZE/2);
    
    //Pull data from the output
    [self.buffer fetchFreshData:arrayData withNumSamples:BUFFER_SIZE];
    
    // Find the FFT
    [self.fftHelper performForwardFFTWithData:arrayData
                   andCopydBMagnitudeToBuffer:_fftMagnitude];
    
    
    // Default direction label
    [self.directionLabel setText:@"Still"];
    
    //Calibrate the baselines
    [self calibrate];
    
    //Find the direction of the hand movement
    [self calculateDoppler];
    
    //Update the FFT graph helper
    [self.graphHelper update];
    
    //Deallocate
    free(arrayData);
    free(_fftMagnitude);
}

//  override the GLKView draw function, from OpenGLES
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    [self.graphHelper draw]; // draw the graph
}

- (IBAction)changeFrequency:(id)sender {
    if (sender == self.frequencySlider) {
        self.frequency = roundl(self.frequencySlider.value);
        self.sliderLabel.text = [NSString stringWithFormat:@"%0.0f Hz", self.frequencySlider.value];
        
        // if sound is playing ie output block exists
        if(self.audioManager.outputBlock){
            [self updateFrequency];
        }
    }
}

- (void) updateFrequency {
    __block double phase = 0.0;
    double phaseIncrement = 2.0*M_PI*((double)self.frequency)/((double)self.audioManager.samplingRate);
    double phaseMax = 2.0*M_PI;
    [self.audioManager setOutputBlock:^(float* data, UInt32 numFrames, UInt32 numChannels){
        for(int i=0; i<numFrames;++i){
            for(int j=0;j<numChannels;++j){
                data[numChannels*i+j] = sin(phase);
            }
            phase+=phaseIncrement;
            if (phase>phaseMax){
                phase -= phaseMax;
            }
        }
        
    }];
    self.calibrateFlag = YES; // calibrate when frequency plays or changes
}

# pragma mark UI Interactions
- (IBAction)playSound:(id)sender {
    [self updateFrequency];
}

- (IBAction)stopSound:(id)sender {
    [self.audioManager setOutputBlock:nil];
}

#pragma mark Doppler Calculations
-(void) calibrate{
    if (self.calibrateFlag) {
        self.baselineLeftAverage = [self calcSideAverage:(NO)];
        self.baselineRightAverage = [self calcSideAverage:(YES)];
        self.calibrateFlag = NO;
    }
}

-(double) calcSideAverage: (BOOL) isRight{
    int peakIndex = (int) (((float)self.frequency)/(((float)self.audioManager.samplingRate)/(((float)BUFFER_SIZE))));
    
    double average = 0;
    if(isRight){
        peakIndex += RANGE_OF_AVERAGE;
    }
    for (int i = peakIndex - RANGE_OF_AVERAGE; i <= peakIndex; ++i) {
        average += _fftMagnitude[i];
    }
    average /= RANGE_OF_AVERAGE;
    return average;
}


-(void) calculateDoppler{
    if(self.audioManager.outputBlock) {
        //Find the frequency peak index
        int peakIndex = (int) (((float)self.frequency)/(((float)self.audioManager.samplingRate)/(((float)BUFFER_SIZE))));
        
        //Graph FFT with the peak in the middle
        [self.graphHelper setGraphData:&_fftMagnitude[peakIndex-50] withDataLength:100 forGraphIndex:2 withNormalization:100 withZeroValue:-70];
        
        //Calculate left average
        double leftValue = [self calcSideAverage:(NO)];
        
        //Calculate right average
        double rightValue = [self calcSideAverage:(YES)];
        
        //Minimum threshold
        double threshold = 10;
        
        //Hand is moving towards the phone
        if(self.baselineRightAverage != 0 && rightValue - self.baselineRightAverage > threshold) {
            [self.directionLabel setText:@"Towards"];
        }
        
        //Hand is moving away from the phone
        if (self.baselineLeftAverage != 0 && leftValue - self.baselineLeftAverage > threshold) {
            [self.directionLabel setText:@"Away"];
        }
        
    }
    
}

@end
