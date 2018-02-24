import g4p_controls.*; //<>//
import java.util.Collections;
import processing.sound.*;

//Initialize standard variables that will be used throughout the program
PApplet parent = this;     //The applet itself
Point drag;                //How much the mouse has moved for scrubbing
Point start;               //The starting point of a line (editing mode)
Point view;                //The position of the view
int mode;                  //The current mode (e.g. playback, note input, etc.)
float cellSize;            //The size in pixels fof each cell
//Events handled by key listeners for the edit mode
boolean scrollUp, scrollDown, scrollRight, scrollLeft, insertNote, deleteNote, keyReleased;
//The instructions for using this application, loaded from a file
String[] instructions;
//The list of all files in this directory
String[] files;
//The selected file
int fileIndex = 0;
//The name of the current file
String currentFile = "";

//The time position in cells (1/16 of a second)
int time = 0;

//Playback-specific variables
//The list of all notes, expressed as lines with start and end points
ArrayList<Line> lines = new ArrayList<Line>();
//The index of the current note about to be played
int position = 0;
//Notes that are currently being played (i.e. notes with oscillators)
ArrayList<Line> playedNotes = new ArrayList<Line>();
//A list of unused oscillators to avoid taking time to initialize more
ArrayList<TriOsc> unusedOscillators = new ArrayList<TriOsc>();


/**
 * This method is called before the first time the application is displayed.
 **/
void setup() {
  //Set up the application.
  size(320, 240);
  surface.setResizable(true);
  frameRate(24);
  //Establish the view point
  view = new Point(0, 0);
  //Load the instructions to display on startup.
  instructions = loadStrings("Instructions.txt");
  //Load the songs.
  loadFiles();
  //Start at the load menu if there are any songs
  if (files.length>0)mode=3;
  else mode = 4;
}

/**
 * Manages the applet after setup()
 * Called every frame
 **/
void draw() {
  //Behave differently based on the current mode
  switch(mode) {
  case 0: //Instructions
    //Fill the background with black
    background(0);
    //Set text color to white
    fill(255);
    //Iterate through the list of instructions and print on screen
    int y = 0; //A line counter
    for (String line : instructions) {
      text(line, 0, (++y)*12); //Write each line on the next unused space
    }
    break; //End of instructions for writing instructions
  case 1: //Editor
    //Fill the background with a semitransparent black color
    fill(0, 128);
    rect(0, 0, width, height);
    //Keyboard-scrolling mechanism 
    if (scrollLeft)view.shift(-int(cellSize), 0);
    if (scrollRight)view.shift(int(cellSize), 0);
    if (scrollDown)view.shift(0, int(cellSize));
    if (scrollUp)view.shift(0, -int(cellSize));
    //Add a new line or finish one if the user requests to do so
    if (insertNote) {
      //Start a note if it hasn't been started
      if (start == null) {
        start = pick();
      } 
      //Finish a note if it has been started
      else {
        lines.add(new Line(start, pick()));
        start = null;
      }
      //Turn off the "insertNote" variable to prevent adding unneccessary notes
      insertNote = false;
    } //End of insert-note code
    //If the user requests to delete a note
    if (deleteNote) {
      //Find the note the user wants to delete
      Point p = pick();
      //Delete the most recent (or last) note with an endpoint that 
      //matches the location of the mouse
      for (int i = lines.size()-1; i >= 0; i --) {
        if (lines.get(i).start.equals(p)||lines.get(i).end.equals(p)) {
          lines.remove(i);
          break; //Do not delete all notes with an enpoint that matches 
          //the location of the mouse
        }
      }
      //Turn off the "deleteNote" variable to prevent unintentional mass-deletion
      deleteNote = false;
    }//End of delete-note condition
    //Mouse-scrubbing functionality (could be rewritten witten with pmouseX and pmouseY)
    if (mousePressed) {
      if (drag == null) {
        drag = new Point(mouseX, mouseY);
      } else {
        view.shift(drag.x-mouseX, drag.y-mouseY);
        drag.x = mouseX;
        drag.y = mouseY;
      }
    } else {
      drag = null;
    }//End of mouse-scrubbing
    //Draw everything
    //Draw grid lines
    drawGridLines();
    //Draw notes
    strokeWeight(8);
    stroke(0, 255, 0);
    for (Line l : lines) {
      l.display();
    }
    //Draw a red line where the user might make a new line
    stroke(255, 0, 0);
    if (start != null) {
      drawLine(start, pick());
    }
    //Draw the note and time positions over anything else
    drawNotePositions();
    drawTimePositions();
    break; //End of editor code
  case 2: //Playback code
    //View changing mechanism
    if (scrollDown)view.shift(0, 16);
    if (scrollUp)view.shift(0, -16);
    if (mousePressed) view.y += pmouseY-mouseY;
    //Keep playing music unless there is none left
    //This code is an if statement (as opposed to a while loop) to 
    //  allow this method to refresh, updating the screen
    if (position<lines.size() || playedNotes.size()>0) {
      //Advance time and view position to continue playing music
      time ++;
      view.x = time*int(cellSize)-width/2;
      //Keep starting new lines that start at the current time
      while (position<lines.size() && lines.get(position).start.x<=time) {
        Line line = lines.get(position);
        //Assign each line an oscillator
        //Make a new oscillator if there aren't any
        if (unusedOscillators.size()==0)
          line.oscillator = new TriOsc(parent);
        //Use an oscillator if available
        else
          line.oscillator = unusedOscillators.remove(0);
        //Add this to the list of notes that are being played
        playedNotes.add(line);
        //Play the note
        line.oscillator.play();
        //Advance the counter that indicates the position of the next line being played
        position ++;
      }//End of while loop
      //Update playing notes
      //This iterates backwards because some notes might be removed
      for (int i = playedNotes.size()-1; i >= 0; i--) {
        //Get the line
        Line line = playedNotes.get(i);
        //If the note is done playing
        if (line.end.x<time) {
          playedNotes.remove(i);
          unusedOscillators.add(line.oscillator);
          line.oscillator.stop();
          line.oscillator = null;
        } else { //If the note is not done playing
          //Play it
          line.play(time);
        }
      }//End of for loop
    }//End of if statement
    //Start drawing stuff
    noStroke(); //Strokes are not healthy anyway
    //Make a pulsing background
    if (time%8==0) {
      fill(0, 0, 64, 50);
      rect(0, 0, width, height);
      strokeWeight(16);
    } else {
      fill(0, 50);
      rect(0, 0, width, height);
      strokeWeight(8);
    }
    //Draw all notes in blue
    stroke(0, 0, 255);
    for (Line l : lines) {
      l.display();
    }
    //Highlight all played notes in yellow
    stroke(255, 255, 0);
    for (Line l : playedNotes) {
      l.display();
    }
    stroke(255, 255, 255);
    line(width/2, 0, width/2, height);
    break;
  case 3://File loader
    if (keyPressed) {
      switch(key) {
      case 'w':
      case 'a':
        if (--fileIndex<0)fileIndex=0;
        break;
      case 's':
      case 'd':
        if (++fileIndex>files.length)fileIndex=files.length;
        break;
      }//End of switch
    }//End of if statement
    if (keyReleased&&key=='\n') {
      if (fileIndex==0)mode=4; //Go to new file mode
      else { //If a file is selected
        currentFile = "songs/"+files[fileIndex-1];
        loadFromFile(currentFile);
        mode = 0;
        incrementMode();
      }//End of if/else statement
    }//End of if statement
    //Begin drawing
    background(0);
    fill(128, 0, 0);
    noStroke();
    rect(0, fileIndex*12, width, 12);
    fill(255, 255, 0);    
    //Draw the "new file" option at the top of the screen
    text("New file", 0, 12);
    //Iterate through the list of files and print on screen
    position = 1; //A line counter
    for (String line : files) {
      text(line, 0, (++position)*12); //Write each line on the next unused space
    }
    break; //End of instructions for drawing file loader
  case 4://New file
    frameRate(40);
    if (keyReleased) {
      if ((key>='A'&&key<='z')||(key>='0'&&key<='9')||key=='-'||key=='_')currentFile+=key;
      else if (int(key)==8&&currentFile.length()>0)currentFile=currentFile.substring(0, currentFile.length()-1);
      else if (key=='\n') {
        currentFile = "songs/"+currentFile+".txt";
        loadFromFile(currentFile);
        mode = 0;
        frameRate(16);
        incrementMode();
      }//End of if/else statement
    }//End of if statement
    //Begin drawing
    background(0);
    fill(128, 0, 0);
    noStroke();
    fill(64, 255, 0);    
    //Draw the "new file" option at the top of the screen
    text("New file", 0, 12);
    //Draw the new file instructions at the bottom of the screen
    text("Type new filename (without extension) and press ENTER", 0, height);
    //Draw a text box
    fill(0,255,0);
    rect(0,20,width, 20);
    //Draw the name of the file being created
    fill(0);
    text(currentFile, 0, 36);
    break;//End of new file mode
  }//End of switch
  keyReleased=false;
}//End of draw method

/**
 * This class is a lightweight version of Processing's standard point class.
 * Less code means less RAM for better performance in small processors
 * I think its features are pretty self-explanatory
 **/
class Point {
  public int x, y;
  Point(int x, int y) {
    this.x = x;
    this.y = y;
  }
  void shift(int dx, int dy) {
    x += dx;
    y += dy;
  }
  boolean equals(Point other) {
    return x == other.x && y == other.y;
  }
}//End of Point class

/**
 * The Line class contains two points (the beginning point and the end point)
 * whose instances represent notes. It might also have an oscillator if it 
 * is being played
 **/
class Line implements Comparable<Line> {
  public Point start, end; //Endpoints of the line
  public TriOsc oscillator;//Optional oscillator
  //Constructor with four integers
  Line(int sx, int sy, int ex, int ey) {
    //Swap points if they're backwards.
    //This is critical for proper playback
    if (sx<=ex) {
      start = new Point(sx, sy);
      end = new Point(ex, ey);
    } else {
      start = new Point(ex, ey);
      end = new Point(sx, sy);
    }
  }
  //Constructor with two Point objects
  Line(Point startPoint, Point endPoint) {
    //Swap points if they're backwards.
    //This is critical for proper playback
    if (startPoint.x<=endPoint.x) {
      start = startPoint;
      end = endPoint;
    } else {
      start = endPoint;
      end = startPoint;
    }
  }//End of constructor
  //Draw the line on the screen. This uses a helper method outside of the class
  void display() {
    drawLine(start, end);
  }
  //Override the compareTo method to allow for sorting in ArrayLists
  @Override
    public int compareTo(Line other) {
    return start.x-other.start.x;
  }
  //Set the values of the oscillator based on the current time
  public void play(float time) {
    //Set the amplitude to 0.05, pan to 0.1, offset to 0, and frequency 
    //  according to time
    oscillator.set(noteToFreq(map(time, start.x, end.x, start.y, end.y)), 0.05, 0.0, 0.1);
  }
  //Creates a string representation of the line, a process reversed 
  //  by an outside method fromString(), which allows a list of lines to fit a file
  //  and vice versa
  @Override 
    public String toString() {
    return ""+start.x+" "+start.y+" "+end.x+" "+end.y;
  }
}//End of Line class

/**
 * Creates a new line from a string, typically a line in a file
 **/
Line fromString(String string) {
  String[] vals = string.split(" ");
  return new Line(Integer.parseInt(vals[0]), 
    Integer.parseInt(vals[1]), 
    Integer.parseInt(vals[2]), 
    Integer.parseInt(vals[3]));
}

/**
 * Draw a set of boxes on the left side of the application denoting the 
 * pitch of each cell
 * Great for editors.
 **/
void drawNotePositions() {
  strokeWeight(1);
  stroke(255, 255, 255);
  for (float i = view.y-view.y%cellSize; i < view.y + height; i += cellSize) {
    fill(round(i/cellSize+3)%12==0?128:0);
    rect(0, i-view.y, 32, cellSize);
    fill(255, 255, 255);
    text(noteToString(round(i/cellSize)), cellSize/4, i-view.y+cellSize-2);
  }
}

/**
 * Draw a set of boxes on the top of the application denoting the 
 * relative time of each cell
 * Great for editors.
 **/
void drawTimePositions() {
  strokeWeight(1);
  stroke(255, 255, 255);
  for (float i = view.x-view.x%cellSize; i < view.x + width; i += cellSize) {
    fill(0, 0, 0);
    rect(i-view.x, 0, cellSize, cellSize);
    if (round(i/cellSize)%8==0) {
      fill(255, 255, 255);
      text(round(i/cellSize/8), i-view.x-cellSize/1.2, cellSize/1.2);
    }
  }
}

/**
 * Draw lines that show the boundries of each cell, highlighting beats and 
 * octaves of "A"
 * Great for editors.
 **/
void drawGridLines() {
  strokeWeight(1);
  for (float i = view.y-view.y%cellSize; i < view.y + height; i += cellSize) {
    if (round(i/cellSize+2)%12==0) {
      stroke(255);
      strokeWeight(4);
    } else {
      stroke(128);
      strokeWeight(1);
    }
    line(0, i-view.y, width, i-view.y);
  }//End of for loop
  for (float i = view.x-view.x%cellSize; i < view.x + width; i += cellSize) {
    if (round(i/cellSize)%8==0) {
      stroke(255);
      strokeWeight(4);
    } else {
      stroke(128);
      strokeWeight(1);
    }
    line(i-view.x, 0, i-view.x, height);
  }//End of for loop
}//End of method for drawing grid lines

/**
 * Create a new point at the position of the mouse based on the size of each 
 * cell, the view coordinates, and the mouse position.
 **/
Point pick() {
  Point p = new Point(int((mouseX+view.x)/cellSize), int((mouseY+view.y)/cellSize));
  if ((mouseY+view.y)/cellSize<0)p.y-=1;
  if ((mouseX+view.x)/cellSize<0)p.x-=1;
  return p;
}

/**
 * Draw a line whose endpoints are Point instances
 * Used in the editor and in the Line class
 **/
void drawLine(Point start, Point end) {
  line(start.x*cellSize-view.x+cellSize/2, start.y*cellSize-view.y+cellSize/2, end.x*cellSize-view.x+cellSize/2, end.y*cellSize-view.y+cellSize/2);
}

/**
 * Converts a note index to a frequency
 **/
float noteToFreq(float note) {
  return 440*pow(0.5, note/12);
}

/**
 * Generates a String representation of a note
 * TODO correct the octave indicator
 **/
String noteToString(int note) {
  String s = "";
  switch(note%12) {
  case 0: 
    s += "A"; 
    break;
  case 1: 
  case -11: 
    s += "Ab"; 
    break;
  case 2: 
  case -10: 
    s += "G"; 
    break;
  case 3: 
  case -9: 
    s += "F#"; 
    break;
  case 4: 
  case -8: 
    s += "F"; 
    break;
  case 5: 
  case -7: 
    s += "E"; 
    break;
  case 6: 
  case -6: 
    s += "Eb"; 
    break;
  case 7: 
  case -5: 
    s += "D"; 
    break;
  case 8: 
  case -4: 
    s += "C#"; 
    break;
  case 9: 
  case -3: 
    s += "C"; 
    break;
  case 10: 
  case -2: 
    s += "B"; 
    break;
  case 11: 
  case -1: 
    s += "Bb"; 
    break;
  }
  note+=note<0?3:2;
  int octave = -note/12;
  if (note>0){octave--;}  
  s += octave;
  return s;
}//End of note-to-string conversion method

/**
 * Called each time a key on the keyboard is pressed, regardless of the editor
 * Handles user requests
 **/
void keyPressed() {
  switch(key) {
  case 'a': 
    scrollLeft = true; 
    break;
  case 'd': 
    scrollRight = true; 
    break;
  case 's': 
    scrollDown = true; 
    break;
  case 'w': 
    scrollUp = true; 
    break;
  case ' ': 
    insertNote = true; 
    break;
  case 'q':
    deleteNote = true;
    break;
  case 'o':
    view.x = 0;
    break;
  case '\t':
    incrementMode();
    break;
    case 'r':
    if(mode==1)createRepeatGUI();
    break;
  }//End of switch
  //If the user presses a button from 1 to 8, insert a new note 
  //  whose duration is that many beats
  if (key>='1'&&key<='8'&&mode==1) {
    Point p = pick();
    lines.add(new Line(p, new Point(p.x+8*(key-'1'+1), p.y)));
    view.x += cellSize*8*(key-'1'+1);
  }
  //Insert a half-note if the user presses "9"
  if (key=='9'&&mode==1) {
    Point p = pick();
    lines.add(new Line(p, new Point(p.x+4, p.y)));
    view.x += cellSize*4;
  }
  //Insert a quarter-note if the user presses "0"
  if (key=='0'&&mode==1) {
    Point p = pick();
    lines.add(new Line(p, new Point(p.x+2, p.y)));
    view.x += cellSize*2;
  }
}//End of key-pressed method

/**
 * Called each time a key on the keyboard is released, regardless of the editor
 * Handles user requests
 **/
void keyReleased() {
  keyReleased=true;
  switch(key) {
  case 'a': 
    scrollLeft = false; 
    break;
  case 'd': 
    scrollRight = false; 
    break;
  case 's': 
    scrollDown = false; 
    break;
  case 'w': 
    scrollUp = false; 
    break;
  case 'o':
    if (mode<3) {
      //Open up a new file
      incrementMode();
      mode = 3;
      break;
    }
  }
}

//Changes the current mode to the next one
void incrementMode() {
  //Save and close
  switch(mode) {
  case 1: //Editor mode
    //Save notes and sort them for playback
    Collections.sort(lines);
    saveToFile(currentFile);
    break;
  case 2: //Playback mode
    //Stop playing all notes
    while (playedNotes.size()>0) {
      Line l = playedNotes.remove(0);
      l.oscillator.stop();
      unusedOscillators.add(l.oscillator);
      l.oscillator = null;
    }//End of while loop
  }//End of switch
  //Now actually increment the mode
  mode ++;
  //Reset the mode to zero if it's three
  mode %= 3;  
  //Flash the screen white (which looks pretty cool behind a black background
  background(255);
  //Change some configurations for the new mode
  switch(mode) {
  case 1: //Editor mode
    cellSize=16;
    view.y*=4;
    break;
  case 2: //Playback mode
    cellSize=6;
    view.y/=4;
    time=-64;
    position=0;
    view.y-=height/2;
    break;
  }//End of switch
}//End of incrementMode() method

/**
 * Converts all the notes to human-readable strings of text
 * and saves them to the file specified
 * Opposite of loadFromFile()
 **/
void saveToFile(String filename) {
  String[] contents = new String[lines.size()];
  for (int i = 0; i < contents.length; i ++)
    contents[i]=lines.get(i).toString();
  saveStrings(filename, contents);
}//End of saveToFile()

/**
 * Reads all human-readable strings of text in the file specified
 * and parses them to fill the list of notes
 * Opposite of saveToFile()
 **/
void loadFromFile(String filename) {
  try {
    lines.clear();
    String[] contents = loadStrings(filename);
    for (String s : contents)
      lines.add(fromString(s));
  }
  catch(Exception e) {
    //Don't do anything if the selected file doesn't exist
    //It will be made eventually on the next save
  };//End of try-catch block
}//End of loadFromFile()


/**
 * This function returns all the files in a directory as an array of Strings
 *
 * Source: Processing.org (https://processing.org/examples/directorylist.html)
 **/
String[] listFileNames(String dir) {
  File file = new File(dir);
  if (file.isDirectory()) {
    String names[] = file.list();
    return names;
  } else {
    // If it's not a directory
    return null;
  }
}

/**
 * This function returns all the files in a directory as an array of File objects
 * This is useful if you want more info about the file
 *
 * Source: Processing.org (https://processing.org/examples/directorylist.html)
 **/
File[] listFiles(String dir) {
  File file = new File(dir);
  if (file.isDirectory()) {
    File[] files = file.listFiles();
    return files;
  } else {
    // If it's not a directory
    return null;
  }
}

/**
 * Finds all files and saves them to the "files" String array
 **/
void loadFiles() {
  files = listFileNames(sketchPath()+"/songs");
}