#!/bin/bash
cd "C:\Users\danie\Desktop\roguelite\scrapwright_intro"

ffmpeg -y -framerate 24 -i "scenes/scene1/frame_%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes/scene1.mp4"
ffmpeg -y -framerate 24 -i "scenes/scene2/frame_%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes/scene2.mp4"
ffmpeg -y -framerate 24 -i "scenes/scene3/frame_%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes/scene3.mp4"
ffmpeg -y -framerate 24 -i "scenes/scene4/frame_%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes/scene4.mp4"
ffmpeg -y -framerate 24 -i "scenes/scene6/frame_%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes/scene6.mp4"
ffmpeg -y -framerate 24 -i "scenes/scene7/frame_%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes/scene7.mp4"
ffmpeg -y -framerate 24 -i "scenes/scene8/frame_%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes/scene8.mp4"
ffmpeg -y -framerate 24 -i "scenes/scene9/frame_%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes/scene9.mp4"

# Scene 5
if [ -f "scenes/scene5_cataclysm.mp4" ]; then
  ffmpeg -y -i "scenes/scene5_cataclysm.mp4" -vf "scale=384:216:flags=neighbor,fps=24" -t 3 -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes/scene5_scaled.mp4"
  ffmpeg -y -i "scenes/scene5_scaled.mp4" -framerate 24 -i "scenes/scene5_overlay/frame_%04d.png" -filter_complex "[1:v]format=rgba[ovr];[0:v][ovr]overlay=0:0:enable='gte(t,2.5)'" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes/scene5.mp4"
fi

cat > scenes/concat_list.txt << EOF
file 'scene1.mp4'
file 'scene2.mp4'
file 'scene3.mp4'
file 'scene4.mp4'
file 'scene5.mp4'
file 'scene6.mp4'
file 'scene7.mp4'
file 'scene8.mp4'
file 'scene9.mp4'
EOF

ffmpeg -y -f concat -safe 0 -i "scenes/concat_list.txt" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes/full_lowres.mp4"
ffmpeg -y -i "scenes/full_lowres.mp4" -vf "scale=1920:1080:flags=neighbor" -c:v libx264 -pix_fmt yuv420p -crf 15 "output/scrapwright_intro_no_audio.mp4"
echo "Done!"