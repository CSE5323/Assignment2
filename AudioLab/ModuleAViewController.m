#import "ModuleAViewController.h"
#import "Novocaine.h"
#import "CircularBuffer.h"
#import "SMUGraphHelper.h"
#import "FFTHelper.h"

#define BUFFER_SIZE 4096
#define EQUALIZER_SIZE 20

@interface ModuleAViewController ()
@property (weak, nonatomic) IBOutlet UILabel *displayedFreq1;
@property (weak, nonatomic) IBOutlet UILabel *displayedFreq2;
@property (weak, nonatomic) IBOutlet UILabel *pianoNote;


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
                [NSNumber numberWithInt:1800]:@"B",
                [NSNumber numberWithInt:1698]:@"D",
                [NSNumber numberWithInt:1600]:@"B",
                [NSNumber numberWithInt:1570]:@"G",
                [NSNumber numberWithInt:1560]:@"A♯/B♭",
                [NSNumber numberWithInt:1500]:@"A",
                [NSNumber numberWithInt:1480]:@"F♯/G♭",
                [NSNumber numberWithInt:1470]:@"D",
                [NSNumber numberWithInt:1440]:@"G♯/A♭",
                [NSNumber numberWithInt:1420]:@"D",
                [NSNumber numberWithInt:1380]:@"F",
                [NSNumber numberWithInt:1350]:@"G",
                [NSNumber numberWithInt:1337]:@"G",
                [NSNumber numberWithInt:1300]:@"F♯/G♭",
                [NSNumber numberWithInt:1250]:@"G",
                [NSNumber numberWithInt:1200]:@"C♯/D♭",
                [NSNumber numberWithInt:1189]:@"F",
                [NSNumber numberWithInt:1175]:@"C",
                [NSNumber numberWithInt:1170]:@"A♯/B♭",
                [NSNumber numberWithInt:1128]:@"E",
                [NSNumber numberWithInt:1115]:@"B",
                [NSNumber numberWithInt:1109]:@"C♯/D♭",
                [NSNumber numberWithInt:1090]:@"D",
                [NSNumber numberWithInt:1085]:@"D♯/E♭",
                [NSNumber numberWithInt:1050]:@"G",
                [NSNumber numberWithInt:1025]:@"C",
                [NSNumber numberWithInt:1018]:@"F♯/G♭",
                [NSNumber numberWithInt:1007]:@"D",
                [NSNumber numberWithInt:1002]:@"A",
                [NSNumber numberWithInt:999]:@"F♯/G♭",
                [NSNumber numberWithInt:985]:@"B",
                [NSNumber numberWithInt:980]:@"D♯/E♭",
                [NSNumber numberWithInt:973]:@"C♯/D♭",
                [NSNumber numberWithInt:972]:@"D",
                [NSNumber numberWithInt:965]:@"F♯/G♭",
                [NSNumber numberWithInt:940]:@"F",
                [NSNumber numberWithInt:930]:@"A♯/B♭",
                [NSNumber numberWithInt:923]:@"F♯/G♭",
                [NSNumber numberWithInt:920]:@"D♯/E♭",
                [NSNumber numberWithInt:900]:@"C",
                [NSNumber numberWithInt:880]:@"A or D",
                [NSNumber numberWithInt:872]:@"F",
                [NSNumber numberWithInt:870]:@"C♯/D♭",
                [NSNumber numberWithInt:869]:@"B",
                [NSNumber numberWithInt:839]:@"A♯/B♭",
                [NSNumber numberWithInt:831]:@"C♯/D♭",
                [NSNumber numberWithInt:829]:@"G♯/A♭ or E",
                [NSNumber numberWithInt:825]:@"E",
                [NSNumber numberWithInt:800]:@"A♯/B♭",
                [NSNumber numberWithInt:780]:@"G or C",
                [NSNumber numberWithInt:777]:@"D",
                [NSNumber numberWithInt:770]:@"D♯/E♭",
                [NSNumber numberWithInt:750]:@"A",
                [NSNumber numberWithInt:730]:@"F♯/G♭ or B",
                [NSNumber numberWithInt:680]:@"F",
                [NSNumber numberWithInt:640]:@"E",
                [NSNumber numberWithInt:630]:@"C",
                [NSNumber numberWithInt:620]:@"D♯/E♭",
                [NSNumber numberWithInt:580]:@"D",
                [NSNumber numberWithInt:540]:@"C♯/D♭",
                [NSNumber numberWithInt:510]:@"C",
                [NSNumber numberWithInt:480]:@"B",
                [NSNumber numberWithInt:450]:@"A♯/B♭",
                [NSNumber numberWithInt:430]:@"A",
                [NSNumber numberWithInt:405]:@"G♯/A♭",
                [NSNumber numberWithInt:385]:@"G",
                [NSNumber numberWithInt:365]:@"F♯/G♭",
                [NSNumber numberWithInt:345]:@"F",
                [NSNumber numberWithInt:325]:@"E",
                [NSNumber numberWithInt:305]:@"D♯/E♭",
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

#pragma mark GLK Inherited Functions
//  override the GLKViewController update function, from OpenGLES
- (void)update{
    
    // initialze arrays for data values
    float* arrayData = malloc(sizeof(float)*BUFFER_SIZE);
    float* fftMagnitude = malloc(sizeof(float)*BUFFER_SIZE/2);
    float* equalizer = malloc(sizeof(float) * EQUALIZER_SIZE);
    
    [self.buffer fetchFreshData:arrayData withNumSamples:BUFFER_SIZE];
    
    //send off for graphing
//    [self.graphHelper setGraphData:arrayData
//                    withDataLength:BUFFER_SIZE
//                     forGraphIndex:0];
    
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
    int dist = BUFFER_SIZE / 40;
    float currentMaxValue = 0;
    for (int i = 1, j = 0; i < BUFFER_SIZE / 2; i++) {
        if (i % dist == 0) {
            currentMaxValue = fftMagnitude[i];
        } else if ((i % dist) != (dist - 1) && currentMaxValue < fftMagnitude[i] && (i % dist) > 0 ) {
            currentMaxValue = fftMagnitude[i];
        } else if (i % dist == dist - 1) {
            equalizer[j++] = currentMaxValue;
        }
    }
    
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


@end
