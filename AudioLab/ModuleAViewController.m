#import "ModuleAViewController.h"
#import "Novocaine.h"
#import "CircularBuffer.h"
#import "SMUGraphHelper.h"
#import "FFTHelper.h"

#define BUFFER_SIZE 4096
#define EQUALIZER_SIZE 20
#define SAMPLING_RATE 44100
#define BUFFER_LENGTH 5

@interface ModuleAViewController ()
@property (weak, nonatomic) IBOutlet UILabel *displayedFreq1;
@property (weak, nonatomic) IBOutlet UILabel *displayedFreq2;
@property (weak, nonatomic) IBOutlet UILabel *pianoNote;
@property (nonatomic) int firstFreq;
@property (nonatomic) int secondFreq;

// =================================================================================================
// AI - Add a switch to the story board to control whether or not the frequency is being captured
@property (weak, nonatomic) IBOutlet UISwitch *captureFreq;
- (IBAction)getFrequency:(UISwitch *)sender;
@property (nonatomic) BOOL getFreq;

// =================================================================================================



@property (strong, nonatomic) Novocaine *audioManager;
@property (strong, nonatomic) CircularBuffer *buffer;
@property (strong, nonatomic) SMUGraphHelper *graphHelper;
@property (strong, nonatomic) FFTHelper *fftHelper;
@property (strong, nonatomic) NSDictionary * pianoNoteTable;
@end



@implementation ModuleAViewController

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
                                        preferredFramesPerSecond:30
                                                       numGraphs:1
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

-(NSDictionary*)pianoNoteTable{ //dictionary of frequencies cooresponding to their note values
    if(!_pianoNoteTable){
        _pianoNoteTable= @{
                [NSNumber numberWithInt:2099]:@"C",
                [NSNumber numberWithInt:1981]:@"B",
                [NSNumber numberWithInt:1873]:@"A♯/B♭",
                [NSNumber numberWithInt:1765]:@"A",
                [NSNumber numberWithInt:1668]:@"F♯/A♭",
                [NSNumber numberWithInt:1571]:@"G",
                [NSNumber numberWithInt:1485]:@"F♯/G♭",
                [NSNumber numberWithInt:1399]:@"F",
                [NSNumber numberWithInt:1324]:@"E",
                [NSNumber numberWithInt:1248]:@"D♯/E♭",
                [NSNumber numberWithInt:1173]:@"D",
                [NSNumber numberWithInt:1108]:@"C♯/D♭",
                [NSNumber numberWithInt:1044]:@"C",
                [NSNumber numberWithInt:990]:@"B",
                [NSNumber numberWithInt:936]:@"A♯/B♭",
                [NSNumber numberWithInt:882]:@"A",
                [NSNumber numberWithInt:829]:@"G♯/A♭",
                [NSNumber numberWithInt:785]:@"G",
                [NSNumber numberWithInt:742]:@"F♯/G♭",
                [NSNumber numberWithInt:699]:@"F",
                [NSNumber numberWithInt:656]:@"E",
                [NSNumber numberWithInt:624]:@"D♯/E♭",
                [NSNumber numberWithInt:592]:@"D",
                [NSNumber numberWithInt:549]:@"C♯/D♭",
                [NSNumber numberWithInt:527]:@"C",
                [NSNumber numberWithInt:495]:@"B",
                [NSNumber numberWithInt:462]:@"A♯/B♭",
                [NSNumber numberWithInt:441]:@"A",
                [NSNumber numberWithInt:419]:@"G♯/A♭",
                [NSNumber numberWithInt:387]:@"G",
                [NSNumber numberWithInt:366]:@"F♯/G♭",
                [NSNumber numberWithInt:355]:@"F",
                [NSNumber numberWithInt:333]:@"E",
                [NSNumber numberWithInt:312]:@"D♯/E♭",
                [NSNumber numberWithInt:290]:@"D",
                [NSNumber numberWithInt:279]:@"C♯/D♭",
                [NSNumber numberWithInt:258]:@"Middle C",
                };
    }
    return _pianoNoteTable;
}


#pragma mark VC Life Cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"view Did Load");
    // Do any additional setup after loading the view, typically from a nib.
    
    [self.graphHelper setBoundsWithTop:0.9 bottom:-0.9 left:-0.9 right:0.9];
    
    self.edgesForExtendedLayout =  NO;
    
    __block ModuleAViewController * __weak  weakSelf = self;
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels){
        [weakSelf.buffer addNewFloatData:data withNumSamples:numFrames];
    }];
    
    [self.audioManager play];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.audioManager pause];
}

-(void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (![self.audioManager playing]) {
        [self.audioManager play];
    }
}

// ==================================================================================================
// AI - This function sets the bool for frequency capturing to true

-(IBAction)getFrequency:(UISwitch *)sender {
    self.getFreq = sender.isOn;
    return;
}

// ==================================================================================================

#pragma mark GLK Inherited Functions
//  override the GLKViewController update function, from OpenGLES
- (void)update{
    
    // initialze arrays for data values
    float* arrayData = malloc(sizeof(float)*BUFFER_SIZE);
    float* fftMagnitude = malloc(sizeof(float)*BUFFER_SIZE/2);
    float* equalizer = malloc(sizeof(float) * EQUALIZER_SIZE);
    
    [self.buffer fetchFreshData:arrayData withNumSamples:BUFFER_SIZE];
    
    // find the FFT
    [self.fftHelper performForwardFFTWithData:arrayData
                   andCopydBMagnitudeToBuffer:fftMagnitude];
    
    // graph the FFT data using the graph helper
    [self.graphHelper setGraphData:fftMagnitude
                    withDataLength:BUFFER_SIZE/2
                     forGraphIndex:0
                 withNormalization:64.0
                     withZeroValue:-60];
    
    
    
    // find the maximum value
    int currentMaxValue;
    int currentMax = 0;
    int max = 0;
    int currentMaxValueIndex = 0;
    for(int i = 0; i < BUFFER_SIZE/2; i++){
        currentMax = fftMagnitude[i];
        if(currentMax > max) {
            max = fftMagnitude[i];
            currentMaxValueIndex = i;
        }
    }
    
    // find the next maximum value
    int currentMax2Value;
    int currentMax2 = 0;
    int max2 = 0;
    int currentMax2ValueIndex = 0;
    for(int i = 0; i < BUFFER_SIZE/2; i++){
        currentMax2 = fftMagnitude[i];
        if(currentMax2 > max2 && i != currentMaxValueIndex) {
            max = fftMagnitude[i];
            currentMax2ValueIndex = i;
        }
    }
    
    if( self.getFreq ) {
        currentMaxValue = self.firstFreq;
        currentMax2Value = self.secondFreq;
    } else {
        currentMaxValue = (currentMaxValueIndex * SAMPLING_RATE) / BUFFER_SIZE;
        currentMax2Value = (currentMax2ValueIndex * SAMPLING_RATE) / BUFFER_SIZE;
    }
    
    
// AI =================================================================================================

    self.firstFreq = currentMaxValue;
    self.secondFreq = currentMax2Value;
    
//======================================================================================================
    
    //displaying the 2 highest frequencies
    self.displayedFreq1.text = [NSString stringWithFormat: @"%iHz", currentMaxValue];
    self.displayedFreq2.text = [NSString stringWithFormat: @"%iHz", currentMax2Value];
    
    //display the notes
    [self displayNote:currentMaxValue];
    
    
    //Add the graph data to the graph helper
//    [self.graphHelper setGraphData:equalizer
//                    withDataLength:EQUALIZER_SIZE
//                     forGraphIndex:2
//                 withNormalization:64.0
//                     withZeroValue:-60];

    // update the graph
    [self.graphHelper update];
    
    //Free/deallocate our arrays
    free(arrayData);
    free(fftMagnitude);
    free(equalizer);
}

//  override the GLKView draw function, from OpenGLES
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    [self.graphHelper draw]; // draw the graph
}

#pragma mark Other Functions
-(void)displayNote:(int) frequency{
    NSArray *keys = self.pianoNoteTable.allKeys;
    while(![keys containsObject:[NSNumber numberWithInteger:frequency]]) {
        if(frequency < 100)
            return;
        frequency--;
    }
    self.pianoNote.text = [self.pianoNoteTable objectForKey:[NSNumber numberWithInteger:frequency]];
    return;
}


@end
