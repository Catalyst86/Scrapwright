@echo off
REM Scrapwright Intro - Video Assembly v3
cd /d "C:\Users\danie\Desktop\roguelite\scrapwright_intro"

echo Encoding scene1...
ffmpeg -y -framerate 24 -i "scenes\scene1\frame_%%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes\scene1.mp4" 2>nul
echo Encoding scene2...
ffmpeg -y -framerate 24 -i "scenes\scene2\frame_%%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes\scene2.mp4" 2>nul
echo Encoding scene3...
ffmpeg -y -framerate 24 -i "scenes\scene3\frame_%%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes\scene3.mp4" 2>nul
echo Encoding scene4...
ffmpeg -y -framerate 24 -i "scenes\scene4\frame_%%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes\scene4.mp4" 2>nul
echo Encoding scene6...
ffmpeg -y -framerate 24 -i "scenes\scene6\frame_%%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes\scene6.mp4" 2>nul
echo Encoding scene7...
ffmpeg -y -framerate 24 -i "scenes\scene7\frame_%%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes\scene7.mp4" 2>nul
echo Encoding scene8...
ffmpeg -y -framerate 24 -i "scenes\scene8\frame_%%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes\scene8.mp4" 2>nul
echo Encoding scene9...
ffmpeg -y -framerate 24 -i "scenes\scene9\frame_%%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes\scene9.mp4" 2>nul

REM Scene 5 (external clip)
if exist "scenes\scene5_cataclysm.mp4" (
  echo Processing Scene 5...
  ffmpeg -y -i "scenes\scene5_cataclysm.mp4" -vf "scale=384:216:flags=neighbor,fps=24" -t 3 -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes\scene5_scaled.mp4" 2>nul
  ffmpeg -y -i "scenes\scene5_scaled.mp4" -framerate 24 -i "scenes\scene5_overlay\frame_%%04d.png" -filter_complex "[1:v]format=rgba[ovr];[0:v][ovr]overlay=0:0:enable='gte(t,2.5)'" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes\scene5.mp4" 2>nul
)

echo Building concat list...
(
  echo file 'scene1.mp4'
  echo file 'scene2.mp4'
  echo file 'scene3.mp4'
  echo file 'scene4.mp4'
  if exist "scenes\scene5.mp4" echo file 'scene5.mp4'
  echo file 'scene6.mp4'
  echo file 'scene7.mp4'
  echo file 'scene8.mp4'
  echo file 'scene9.mp4'
) > "scenes\concat_list.txt"

echo Concatenating...
ffmpeg -y -f concat -safe 0 -i "scenes\concat_list.txt" -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes\full_lowres.mp4" 2>nul

echo Upscaling to 1920x1080...
ffmpeg -y -i "scenes\full_lowres.mp4" -vf "scale=1920:1080:flags=neighbor" -c:v libx264 -pix_fmt yuv420p -crf 15 "output\scrapwright_intro_no_audio.mp4" 2>nul

REM Add audio: ffmpeg -y -i "output\scrapwright_intro_no_audio.mp4" -i "audio\intro_music.mp3" -c:v copy -c:a aac -b:a 192k -shortest "output\scrapwright_intro.mp4"
echo.
echo Done! Output: output\scrapwright_intro_no_audio.mp4
pause