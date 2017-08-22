module arxvideo;
import armos.graphics.texture;
import ffmpeg.libavformat.avformat;
import ffmpeg.libavutil.avutil;
import ffmpeg.libavcodec.avcodec;
import ffmpeg.libavutil.mem;
import ffmpeg.libswscale.swscale;

/++
+/
class VideoTexture : Texture{
    public{
        VideoTexture load(in string path){
            _video = (new Video).load(path);
            return this;
        }
    }//public

    private{
        Video _video;
    }//private
}//class VideoTexture

/++
+/
class Video {
    public{
        this(){
            av_register_all();
            avformat_network_init();
        }

        ~this(){
            if(_hasClosed)close();
        }

        Video load(in string path){
            auto formatContext = path.openVideo;
            findStreamInfo(formatContext);
            dumpFormat(formatContext, path);
            auto stream = findStream(formatContext);
            stream.codec.width = 720;
            stream.codec.height = 720;
            import std.stdio;
            stream.codec.width.writeln;
            stream.codec.height.writeln;
            auto codecContext = stream.codec;
            auto decoder = avcodec_find_decoder(stream.codec.codec_id);
            openCodec(codecContext, decoder);
            AVFrame* avFrame;
            AVFrame* glFrame;
            allocateFrames(avFrame, glFrame, codecContext.width, codecContext.height);
            auto packet = AVPacket();
            
            _avFrame = avFrame;
            _glFrame = glFrame;
            _formatContext = formatContext;
            _codecContext  = codecContext;
            _packet = &packet;
            
            SwsContext swsContext;
            return this;
        }

        Video close(){
            if (_avFrame)       av_free(_avFrame);
            if (_glFrame)       av_free(_glFrame);
            if (_packet)        av_free(_packet);
            if (_codecContext)  avcodec_close(_codecContext);
            if (_formatContext) avformat_free_context(_formatContext);
            avformat_close_input(&_formatContext);
            _hasClosed = true;
            return this;
        }

        int width()const{
            return _codecContext.width;
        }

        int height()const{
            return _codecContext.height;
        }
    }//public

    private{
        AVFormatContext* _formatContext;
        AVCodecContext* _codecContext;
        AVFrame* _avFrame;
        AVFrame* _glFrame;
        AVPacket* _packet;
        bool _hasClosed = false;

    }//private
}//class Video

private{
    AVFormatContext* openVideo(in string path){
        AVFormatContext* formatContext;
        assert(avformat_open_input(&formatContext, path.ptr, null, null) >= 0, "failed to open input");
        return formatContext;
    }

    void findStreamInfo(AVFormatContext* formatContext){
        assert(avformat_find_stream_info(formatContext, null) >= 0, "failed to get strea info");
    }

    void dumpFormat(AVFormatContext* formatContext, in string path){
        av_dump_format(formatContext, 0, path.ptr, 0);
    }

    AVStream* findStream(AVFormatContext* formatContext){
        size_t streamIndex;
        for (size_t i = 0; i < formatContext.nb_streams; i++){
            if(formatContext.streams[i].codec.codec_type == AVMediaType.AVMEDIA_TYPE_VIDEO){
                streamIndex = i;
                break;
            }
        }
        assert(streamIndex >= 0, "failed to find video stream");
        return formatContext.streams[streamIndex];
    }

    void openCodec(AVCodecContext* codecContext, AVCodec* decoder){
        assert(avcodec_open2(codecContext, decoder, null) >= 0, "failed to open codec");
    }

    void allocateFrames(AVFrame* avFrame, AVFrame* glFrame, int width, int height){
        avFrame = av_frame_alloc();
        glFrame = av_frame_alloc();
        int size = avpicture_get_size(AVPixelFormat.AV_PIX_FMT_RGB24,
                                      width, 
                                      height);
        
        // ubyte* internalBuffer = cast(ubyte*)av_malloc(size * ubyte.sizeof);
        ubyte[] internalBuffer = new ubyte[](size);
        
        avpicture_fill(cast(AVPicture*)glFrame,
                       internalBuffer.ptr,
                       AVPixelFormat.AV_PIX_FMT_RGB24, 
                       width,
                       height);
    }

    bool readFrame(AVFormatContext* formatContext,
                   AVCodecContext* codecContext,
                   AVPacket* packet,
                   in int streamIndex,
                   AVFrame* avFrame,
                   AVFrame* glFrame,
                   SwsContext* swsContext){
        do {
            if(av_read_frame(formatContext, packet) < 0){
                av_free_packet(packet);
                return false;
            }

            if(packet.stream_index == streamIndex){
                int frameFinished = 0;
                
                if(avcodec_decode_video2(codecContext, avFrame, &frameFinished, packet) < 0){
                    av_free_packet(packet);
                    return false;
                }

                if(frameFinished){
                    if(!swsContext){
                        swsContext = sws_getContext(codecContext.width, codecContext.height,
                                                    codecContext.pix_fmt,
                                                    codecContext.width, codecContext.height, AVPixelFormat.AV_PIX_FMT_RGB24,
                                                    SWS_BICUBIC, null, null, null);
                    }

                    sws_scale(swsContext,
                              avFrame.data.ptr, avFrame.linesize.ptr,
                              0, codecContext.height,
                              glFrame.data.ptr, glFrame.linesize.ptr);

                    // glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0,
                    //                 codecContext.width, codecContext.height,
                    //                 GL_RGB, GL_UNSIGNED_BYTE, glFrame.data[0]);
                }
            }
            av_free_packet(packet);
        } while (packet.stream_index != streamIndex);
        return true;
    }
}
