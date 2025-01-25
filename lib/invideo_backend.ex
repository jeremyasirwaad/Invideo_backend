defmodule InvideoBackend.Router do
  use Plug.Router
  use HTTPoison.Base

  plug :match
  plug :dispatch

  # Add CORS headers to the response
  defp add_cors_headers(conn) do
    conn
    |> Plug.Conn.put_resp_header("access-control-allow-origin", "*")
    |> Plug.Conn.put_resp_header("access-control-allow-methods", "GET, POST, OPTIONS")
    |> Plug.Conn.put_resp_header("access-control-allow-headers", "Content-Type, Authorization")
  end

  post "/process" do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    conn = add_cors_headers(conn)

    case Jason.decode(body) do
      {:ok, %{"input" => input}} ->
        response = call_openai_api(input)

        case response do
          {:ok, response_body} ->
            send_resp(conn, 200, response_body)

          {:error, reason} ->
            send_resp(conn, 500, Jason.encode!(%{error: reason}))
        end

      {:error, _reason} ->
        send_resp(conn, 400, Jason.encode!(%{error: "Invalid JSON"}))
    end
  end

  # Handle OPTIONS requests for CORS preflight
  options _ do
    conn
    |> add_cors_headers()
    |> send_resp(204, "")
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  defp call_openai_api(input) do
    # Replace with your actual API key
    api_key = ""

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    body = Jason.encode!(%{
      model: "gpt-4o",
      response_format: %{type: "json_object"},
      messages: [
        %{
          role: "system",
          content: "You are a helpful assistant who creates a very simple sharder code that will work for the below code. return only the sharder code text as string, no need to assign to any variables and etc // ShaderRenderer.js import React, { useRef, useMemo } from 'react'; import { Canvas, useFrame } from '@react-three/fiber'; import { ShaderMaterial, PlaneGeometry, MeshBasicMaterial } from 'three'; import { extend } from '@react-three/fiber'; import PropTypes from 'prop-types'; // Extend will make the shader material available as a JSX element extend({ ShaderMaterial }); const ShaderMesh = ({ shader }) => { const meshRef = useRef(); // Split the combined shader into vertex and fragment shaders const [vertexShader, fragmentShader] = useMemo(() => { const [vShader, fShader] = shader.split('#fragment'); return [vShader.replace('#vertex', '').trim(), fShader.trim()]; }, [shader]); // Create the shader material const shaderMaterial = useMemo(() => { return new ShaderMaterial({ vertexShader, fragmentShader, uniforms: { u_time: { value: 0.0 }, // Add more uniforms here if needed }, // If you need to enable lighting or other features, set the appropriate flags // lights: true, }); }, [vertexShader, fragmentShader]); // Update the uniform 'u_time' on each frame useFrame((state, delta) => { shaderMaterial.uniforms.u_time.value += delta; }); return ( <mesh ref={meshRef} material={shaderMaterial}> {/* Default Geometry: Plane */} {/* You can change this to other geometries like boxGeometry, sphereGeometry, etc. */} <planeGeometry args={[2, 2, 1, 1]} /> </mesh> ); }; ShaderMesh.propTypes = { shader: PropTypes.string.isRequired, }; const ShaderRenderer = ({ shader }) => { return ( <Canvas> <ShaderMesh shader={shader} /> </Canvas> ); }; ShaderRenderer.propTypes = { shader: PropTypes.string.isRequired, }; export default ShaderRenderer; You should return in json format. Format: {“code”: <sharder as string here>} "
        },
        %{role: "user", content: input}
      ]
    })

    url = "https://api.openai.com/v1/chat/completions"

    case HTTPoison.post(url, body, headers, timeout: 30_000, recv_timeout: 30_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %HTTPoison.Response{status_code: status, body: response_body}} ->
        {:error, "OpenAI API returned status #{status}: #{response_body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end
end
