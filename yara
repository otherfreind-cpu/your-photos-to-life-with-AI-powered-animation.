<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Photo to Motion Studio</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
    <script type="importmap">
      {
        "imports": {
          "@google/genai": "https://aistudiocdn.com/@google/genai@^1.22.0",
          "react-dom/": "https://aistudiocdn.com/react-dom@^19.2.0/",
          "react/": "https://aistudiocdn.com/react@^19.2.0/",
          "react": "https://aistudiocdn.com/react@^19.2.0"
        }
      }
    </script>
  </head>
  <body class="bg-gray-900 text-white">
    <div id="root"></div>
    <script type="text/babel" data-type="module">
      import React, { useState, useCallback } from 'react';
      import ReactDOM from 'react-dom/client';
      import { GoogleGenAI } from "@google/genai";

      // From components/Icons.tsx
      const UploadIcon = () => (
          <svg className="w-8 h-8 mb-4 text-gray-500" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 20 16">
              <path stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 13h3a3 3 0 0 0 0-6h-.025A5.56 5.56 0 0 0 16 6.5 5.5 5.5 0 0 0 5.207 5.021C5.137 5.017 5.071 5 5 5a4 4 0 0 0 0 8h2.167M10 15V6m0 0L8 8m2-2 2 2"/>
          </svg>
      );

      const FilmIcon = () => (
          <svg className="w-6 h-6" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 20 20">
              <path stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 3h12a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Zm0 2v2m0 4v2m0 4v2m4-12v2m0 4v2m0 4v2m4-12v2m0 4v2m0 4v2m4-12v2m0 4v2m0 4v2"/>
          </svg>
      );

      const DownloadIcon = () => (
          <svg className="w-5 h-5" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 20 19">
              <path stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 15h.01M4 12.5a3.5 3.5 0 1 1 7 0 3.5 3.5 0 0 1-7 0Zm0 0h-2M15 5h.01M4 5h2m0 0a2.5 2.5 0 1 1 5 0 2.5 2.5 0 0 1-5 0Zm9 .5a3.5 3.5 0 1 1 7 0 3.5 3.5 0 0 1-7 0Zm0 0h-2"/>
          </svg>
      );

      // From services/geminiService.ts
      const POLLING_INTERVAL_MS = 10000; // 10 seconds

      const generateVideo = async (
        base64Image,
        mimeType,
        prompt,
        onStatusUpdate
      ) => {
        if (!process.env.API_KEY) {
          throw new Error("API_KEY environment variable not set");
        }

        const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });

        try {
          onStatusUpdate('Sending request to AI model...');
          let operation = await ai.models.generateVideos({
            model: 'veo-2.0-generate-001',
            prompt: prompt,
            image: {
              imageBytes: base64Image,
              mimeType: mimeType,
            },
            config: {
              numberOfVideos: 1,
            },
          });

          onStatusUpdate('Video generation in progress... This may take a few minutes.');
          let pollCount = 1;
          while (!operation.done) {
            await new Promise(resolve => setTimeout(resolve, POLLING_INTERVAL_MS));
            onStatusUpdate(`Checking status (Attempt #${pollCount++})... Please be patient.`);
            operation = await ai.operations.getVideosOperation({ operation: operation });
          }

          onStatusUpdate('Generation complete! Retrieving video data...');

          const downloadLink = operation.response?.generatedVideos?.[0]?.video?.uri;
          if (!downloadLink) {
            throw new Error("Video generation succeeded, but no download link was provided.");
          }
          
          const videoUrl = `${downloadLink}&key=${process.env.API_KEY}`;
          
          onStatusUpdate('Fetching video file...');
          const response = await fetch(videoUrl);

          if (!response.ok) {
              throw new Error(`Failed to fetch the generated video. Status: ${response.status}`);
          }

          const videoBlob = await response.blob();
          onStatusUpdate('Video ready!');
          return URL.createObjectURL(videoBlob);
        } catch (error) {
          console.error("Error in generateVideo service:", error);
          if (error instanceof Error) {
            throw new Error(`AI service error: ${error.message}`);
          }
          throw new Error("An unknown error occurred while communicating with the AI service.");
        }
      };

      // From App.tsx

      // Helper function to convert file to base64
      const fileToBase64 = (file) => {
        return new Promise((resolve, reject) => {
          const reader = new FileReader();
          reader.readAsDataURL(file);
          reader.onload = () => {
            const result = reader.result;
            const base64 = result.split(',')[1];
            resolve({ base64, mimeType: file.type });
          };
          reader.onerror = (error) => reject(error);
        });
      };

      const ImageUploader = ({ onImageUpload, previewUrl }) => {
        const handleFileChange = (e) => {
          if (e.target.files && e.target.files[0]) {
            onImageUpload(e.target.files[0]);
          }
        };

        const handleDragOver = (e) => {
          e.preventDefault();
        };

        const handleDrop = (e) => {
          e.preventDefault();
          if (e.dataTransfer.files && e.dataTransfer.files[0]) {
            onImageUpload(e.dataTransfer.files[0]);
          }
        };

        return (
          <div className="w-full">
            <label 
              htmlFor="image-upload" 
              className={`flex flex-col items-center justify-center w-full h-64 border-2 border-dashed rounded-lg cursor-pointer transition-colors
                ${previewUrl ? 'border-green-400 bg-green-900/20' : 'border-gray-600 bg-gray-800 hover:bg-gray-700'}`}
              onDragOver={handleDragOver}
              onDrop={handleDrop}
            >
              {previewUrl ? (
                <img src={previewUrl} alt="Image preview" className="object-contain h-full w-full rounded-lg p-2" />
              ) : (
                <div className="flex flex-col items-center justify-center pt-5 pb-6">
                  <UploadIcon />
                  <p className="mb-2 text-sm text-gray-400"><span className="font-semibold">Click to upload</span> or drag and drop</p>
                  <p className="text-xs text-gray-500">JPG or PNG</p>
                </div>
              )}
              <input id="image-upload" type="file" className="hidden" onChange={handleFileChange} accept="image/jpeg, image/png" />
            </label>
          </div>
        );
      };

      const Step = ({ number, title, children }) => (
        <div className="w-full space-y-4">
          <div className="flex items-center gap-3">
            <div className="flex items-center justify-center w-8 h-8 text-lg font-bold rounded-full bg-indigo-600 text-white">
              {number}
            </div>
            <h2 className="text-xl font-semibold text-gray-200">{title}</h2>
          </div>
          {children}
        </div>
      );

      function App() {
        const [image, setImage] = useState(null);
        const [prompt, setPrompt] = useState('');
        const [isLoading, setIsLoading] = useState(false);
        const [statusMessage, setStatusMessage] = useState('');
        const [videoUrl, setVideoUrl] = useState(null);
        const [error, setError] = useState(null);

        const handleImageUpload = useCallback(async (file) => {
          if (!['image/jpeg', 'image/png'].includes(file.type)) {
            setError('Invalid file type. Please upload a JPG or PNG image.');
            return;
          }
          setError(null);
          setVideoUrl(null);
          const { base64, mimeType } = await fileToBase64(file);
          setImage({ file, base64, mimeType, previewUrl: URL.createObjectURL(file) });
        }, []);

        const handleSubmit = async () => {
          if (!image || !prompt) {
            setError('Please upload an image and provide animation instructions.');
            return;
          }

          setIsLoading(true);
          setError(null);
          setVideoUrl(null);
          setStatusMessage('Initializing animation process...');

          try {
            const generatedUrl = await generateVideo(
              image.base64,
              image.mimeType,
              prompt,
              (message) => setStatusMessage(message)
            );
            setVideoUrl(generatedUrl);
          } catch (e) {
            console.error(e);
            setError(e instanceof Error ? e.message : 'An unknown error occurred during video generation.');
          } finally {
            setIsLoading(false);
            setStatusMessage('');
          }
        };

        return (
          <div className="min-h-screen bg-gray-900 text-gray-100 flex flex-col items-center p-4 sm:p-6 lg:p-8">
            <div className="w-full max-w-2xl mx-auto">
              <header className="text-center mb-10">
                <h1 className="text-4xl sm:text-5xl font-extrabold text-transparent bg-clip-text bg-gradient-to-r from-purple-400 to-indigo-600">
                  Photo to Motion Studio
                </h1>
                <p className="mt-2 text-lg text-gray-400">Bring your photos to life with AI-powered animation.</p>
              </header>

              <main className="space-y-12">
                <Step number={1} title="Upload Your Starting Image">
                  <ImageUploader onImageUpload={handleImageUpload} previewUrl={image?.previewUrl || null} />
                </Step>

                <Step number={2} title="Describe Animation">
                  <textarea
                    value={prompt}
                    onChange={(e) => setPrompt(e.target.value)}
                    placeholder="Describe how you want to animate the image. For example: 'Make the waterfall move and add a subtle mist effect,' or 'Slowly zoom in on the person's face and make them blink.'"
                    className="w-full h-32 p-4 bg-gray-800 border-2 border-gray-600 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-colors placeholder-gray-500"
                    disabled={isLoading}
                  />
                </Step>

                {error && <div className="bg-red-900/50 border border-red-500 text-red-300 px-4 py-3 rounded-lg text-center">{error}</div>}

                <div className="text-center">
                  <button
                    onClick={handleSubmit}
                    disabled={isLoading || !image || !prompt}
                    className="inline-flex items-center justify-center gap-2 px-8 py-4 font-semibold text-white bg-indigo-600 rounded-lg shadow-lg hover:bg-indigo-500 disabled:bg-gray-700 disabled:cursor-not-allowed disabled:text-gray-400 transition-all duration-300 transform hover:scale-105 disabled:scale-100"
                  >
                    {isLoading ? (
                      <>
                        <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                          <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                        </svg>
                        Generating...
                      </>
                    ) : (
                      <>
                        <FilmIcon /> Animate Image
                      </>
                    )}
                  </button>
                </div>

                {isLoading && (
                  <div className="text-center text-indigo-300 p-4 bg-gray-800 rounded-lg">
                    <p>{statusMessage}</p>
                  </div>
                )}

                {videoUrl && (
                  <div className="w-full space-y-4 pt-6">
                    <h2 className="text-2xl font-bold text-center text-gray-200">Your Animation is Ready!</h2>
                    <div className="aspect-video w-full bg-black rounded-lg overflow-hidden border-2 border-indigo-500 shadow-2xl shadow-indigo-500/20">
                      <video src={videoUrl} controls autoPlay loop className="w-full h-full object-contain" />
                    </div>
                    <div className="text-center">
                      <a
                        href={videoUrl}
                        download={`animation-${Date.now()}.mp4`}
                        className="inline-flex items-center justify-center gap-2 px-6 py-3 font-semibold text-white bg-green-600 rounded-lg hover:bg-green-500 transition-colors"
                      >
                        <DownloadIcon /> Download Video
                      </a>
                    </div>
                  </div>
                )}
              </main>
            </div>
          </div>
        );
      }

      // From index.tsx
      const rootElement = document.getElementById('root');
      if (!rootElement) {
        throw new Error("Could not find root element to mount to");
      }

      const root = ReactDOM.createRoot(rootElement);
      root.render(
        <React.StrictMode>
          <App />
        </React.StrictMode>
      );
    </script>
  </body>
</html>
