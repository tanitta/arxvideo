static import ar = armos;
import arxvideo;

class MainApp : ar.app.BaseApp{
    this(){}

    override void setup(){
        videoTexture = new VideoTexture;
        videoTexture.load("data/test.mov");
    }

    override void update(){}

    override void draw(){}

    override void keyPressed(ar.utils.KeyType key){}

    override void keyReleased(ar.utils.KeyType key){}

    override void mouseMoved(ar.math.Vector2i position, int button){}

    override void mousePressed(ar.math.Vector2i position, int button){}

    override void mouseReleased(ar.math.Vector2i position, int button){}

    VideoTexture videoTexture;
}

void main(){ar.app.run(new MainApp);}
