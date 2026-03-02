// Anime4K 3D Graphics Upscaler (Ultra Small)
// Based on Anime4K project by bloc97

import bgfx;

#ifdef BG_FP16
#pragma warning(disable: 3557)
#endif

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH * 2", "INPUT_HEIGHT * 2")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState sam1;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
Texture2D tex1;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
RWTexture2D<float4> tex1_UAV;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
Texture2D tex2;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
RWTexture2D<float4> tex2_UAV;

[bgfx::EFFECT("Anime4K 3D Upscale US", 2)]
[bgfx::CATEGORY("Anime4K")]
[bgfx::DESCRIPTION("2x upscaler for 3D graphics content. Ultra small variant offers fastest performance with basic quality.")]
[bgfx::FP16]
[bgfx::PASS(1, "Feature Extraction Conv-4x3x3x3")]
[bgfx::PASS_IO("INPUT", "tex1_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    half3 src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const half4 sr = half4(INPUT.GatherRed(sam, tpos));
            const half4 sg = half4(INPUT.GatherGreen(sam, tpos));
            const half4 sb = half4(INPUT.GatherBlue(sam, tpos));

            src[i][j] = half3(sr.w, sg.w, sb.w);
            src[i][j + 1] = half3(sr.x, sg.x, sb.x);
            src[i + 1][j] = half3(sr.z, sg.z, sb.z);
            src[i + 1][j + 1] = half3(sr.y, sg.y, sb.y);
        }
    }

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            uint2 destPos = gxy + uint2(i - 1, j - 1);

            bool shouldProcess = true;
            if (i != 1 || j != 1)
            {
                if (destPos.x >= inputSize.x || destPos.y >= inputSize.y)
                {
                    shouldProcess = false;
                }
            }

            if (shouldProcess)
            {
                half4 result = half4(0.0033260486h, 0.0027453774h, 0.002706769h, -0.0022023292h);
                result = MulAdd(src[i - 1][j - 1], half3x4(0.020295616h, 0.26657984h, -0.28531083h, 0.041052748h, 0.11729335h, 0.4042445h, -0.5860672h, 0.098661005h, 0.07756054h, 0.32493782h, -0.38677853h, 0.029859459h), result);
                result = MulAdd(src[i - 1][j], half3x4(-0.28257942h, 0.46859467h, 0.07703674h, -0.05280326h, -0.46674755h, 0.6592401h, 0.28513643h, -0.059969574h, -0.37685588h, 0.54568315h, 0.1845521h, -0.002367634h), result);
                result = MulAdd(src[i - 1][j + 1], half3x4(-0.14898707h, -0.088150576h, -0.09723321h, 0.48359355h, -0.27636692h, -0.09316871h, -0.15453896h, 0.68637407h, -0.19012338h, -0.13310172h, -0.13367014h, 0.61284137h), result);
                result = MulAdd(src[i][j - 1], half3x4(0.36225644h, 0.14732021h, -0.17000826h, -0.039856624h, 0.50175637h, 0.11733988h, -0.080232985h, -0.059622094h, 0.3199943h, 0.14199091h, -0.08377198h, -0.058804136h), result);
                result = MulAdd(src[i][j], half3x4(0.42444956h, -0.7508643h, 0.77660984h, -0.5920436h, 0.6205736h, -1.1258985h, 0.91925675h, -0.854362h, 0.5576168h, -0.84702957h, 0.6147012h, -0.7004013h), result);
                result = MulAdd(src[i][j + 1], half3x4(0.047896724h, -0.018435799h, -0.07901341h, 0.14234425h, 0.12161554h, -0.03132901h, -0.049536135h, 0.16390118h, 0.054683182h, -0.054823015h, -0.019946543h, 0.058345634h), result);
                result = MulAdd(src[i + 1][j - 1], half3x4(-0.60845935h, -0.0062592463h, 0.17769416h, 0.00643066h, -0.8315386h, 0.010405371h, 0.227901h, 0.054893702h, -0.63039875h, -0.02128892h, 0.20843753h, 0.054094747h), result);
                result = MulAdd(src[i + 1][j], half3x4(0.24499738h, -0.11924165h, -0.16513842h, -0.012650152h, 0.21676576h, -0.14322694h, -0.08526706h, -0.0122355h, 0.26050088h, -0.115822464h, -0.11147918h, -0.018665116h), result);
                result = MulAdd(src[i + 1][j + 1], half3x4(-0.06054074h, 0.094478205h, -0.23038268h, 0.008782032h, -0.028404612h, 0.22320247h, -0.4821615h, -0.0055871494h, -0.047503285h, 0.15098651h, -0.26161456h, 0.029869653h), result);

                tex1_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(2, "Feature Processing Conv-4x3x3x8")]
[bgfx::PASS_IO("tex1", "tex2_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass2(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    half4 src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const half4 sr = half4(tex1.GatherRed(sam, tpos));
            const half4 sg = half4(tex1.GatherGreen(sam, tpos));
            const half4 sb = half4(tex1.GatherBlue(sam, tpos));
            const half4 sa = half4(tex1.GatherAlpha(sam, tpos));

            src[i][j] = half4(sr.w, sg.w, sb.w, sa.w);
            src[i][j + 1] = half4(sr.x, sg.x, sb.x, sa.x);
            src[i + 1][j] = half4(sr.z, sg.z, sb.z, sa.z);
            src[i + 1][j + 1] = half4(sr.y, sg.y, sb.y, sa.y);
        }
    }

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            uint2 destPos = gxy + uint2(i - 1, j - 1);

            bool shouldProcess = true;
            if (i != 1 || j != 1)
            {
                if (destPos.x >= inputSize.x || destPos.y >= inputSize.y)
                {
                    shouldProcess = false;
                }
            }

            if (shouldProcess)
            {
                half4 result = half4(-0.0016514715h, -0.0038319482h, -0.0073834592h, -0.0059920377h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(-0.26565167h, 0.03297807h, 0.08926044h, 0.029984077h, -0.20809028h, 0.00351991h, 0.15452495h, 0.09963063h, -0.13773972h, 0.01029457h, 0.045066427h, 0.1247363h, -0.12714206h, 0.010659472h, -0.06463583h, -0.0154152885h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(0.0030874603h, -0.04652791h, -0.23016497h, -0.46789864h, 0.16454394h, -0.12389561h, -0.026154622h, -0.008619661h, -0.10648254h, -0.10581639h, 0.038306713h, -0.038339432h, 0.09716571h, -0.037978917h, -0.075691506h, -0.0712344h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(-0.22059305h, 0.18160829h, 0.027175324h, -0.09482166h, -0.07888123h, 0.12431242h, 0.02432025h, -0.121108614h, -0.0720631h, -0.0138989305h, -0.02100737h, -0.027440425h, -0.06610268h, 0.115165174h, 0.02048676h, -0.0409675h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(-0.043652806h, 0.0134993605h, 0.0030924282h, -0.03314738h, 0.27716368h, 0.05542831h, -0.28217152h, -0.017624432h, -0.11218036h, 0.009025405h, -0.13453043h, -0.05897923h, 0.32378325h, -0.0070016393h, -0.04415195h, 0.10701437h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(-0.23568924h, 0.028462708h, 0.11686719h, 0.025355088h, -0.088295944h, 0.033592343h, 0.22703041h, 0.45683298h, -0.0860751h, -0.17487867h, -0.048110463h, 0.0030137985h, -0.031168368h, 0.075628504h, 0.24791549h, 0.13066974h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(0.04647855h, -0.42392284h, -0.19600202h, -0.07964123h, 0.059082046h, -0.16060755h, -0.12607971h, 0.011384242h, 0.021775302h, -0.10103477h, -0.09646511h, -0.0333935h, 0.017039102h, -0.14098461h, -0.0981411h, -0.0023695084h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(-0.016526148h, -0.0006880693h, 0.030872462h, -0.018204063h, -0.025757499h, -0.01037187h, 0.21834393h, 0.09965417h, -0.057800297h, -0.029975737h, -0.00684766h, 0.05800057h, 0.1683585h, -0.057496388h, 0.7087625h, 0.2665085h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(0.059480842h, -0.05298332h, -0.06537449h, -0.06439374h, 0.09735456h, -0.19591855h, -0.42987427h, -0.012228564h, 0.03898561h, -0.22284365h, -0.24668825h, -0.06651606h, -0.087776355h, 0.3200755h, -0.050433923h, -0.100411855h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(-0.053572096h, 0.16021295h, 0.071161h, -0.06335539h, 0.015909042h, 0.20072727h, 0.08304887h, 0.05335472h, -0.03467755h, -0.02854195h, 0.044690188h, 0.0045897495h, -0.02924389h, 0.16038977h, 0.06578487h, 0.027916174h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(0.11840388h, -0.011793132h, -0.004042257h, -0.116042845h, 0.17388786h, -0.031351876h, -0.1152781h, -0.13333467h, 0.2354002h, -0.045496088h, -0.16311322h, -0.06960798h, 0.11317423h, 0.005508318h, 0.15634489h, 0.061211936h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(0.009622364h, 0.03682801h, 0.20317583h, 0.41673073h, 0.00662247h, 0.11070694h, -0.020392824h, 0.13875432h, 0.036129113h, 0.073727116h, -0.114370294h, 0.042431634h, -0.0446233h, 0.0734258h, 0.09814352h, 0.09335129h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(0.057668976h, -0.21368256h, -0.029979514h, 0.039450984h, 0.16685131h, -0.15085255h, -0.042412136h, 0.15757313h, 0.110782996h, -0.07277766h, -0.035268076h, 0.06094599h, 0.088834405h, -0.07145625h, 0.0009840949h, 0.04932651h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(-0.00010679438h, 0.0036139274h, -0.001123274h, -0.10001404h, -0.035231482h, -0.008196208h, 0.24442215h, 0.13503289h, -0.082656465h, -0.061868448h, -0.34716147h, -0.22398905h, -0.00626325h, 0.063109376h, 0.10340223h, 0.030913284h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(-0.11526892h, -0.01739956h, -0.1781953h, -0.27035302h, 0.13689406h, -0.04320452h, -0.19705579h, -0.16808036h, -0.20343314h, -0.13549826h, -0.08057608h, -0.16109829h, 0.16905797h, 0.00077912246h, -0.14143418h, 2.5004636e-05h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(-0.110721245h, 0.33579257h, 0.14410733h, -0.06675498h, 0.002022071h, 0.18419205h, 0.09936456h, 0.07311257h, 0.0064584822h, -0.031634383h, 0.095907465h, 0.031282485h, 0.0051860735h, 0.25176755h, 0.089756206h, 0.052209254h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(-0.06346731h, 0.009824449h, -0.02733463h, -0.06341941h, 0.17385058h, 0.0067438814h, -0.15083039h, -0.09102664h, 0.065680414h, -0.06668183h, -0.18805085h, -0.02785943h, 0.06386912h, 0.09340653h, 0.0032584765h, 0.060902752h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(-0.061221372h, -0.0020573896h, 0.063335806h, 0.046898697h, -0.030530764h, 0.27301106h, 0.23682626h, 0.14863367h, -0.034555666h, 0.024279105h, -0.176423h, 0.018163674h, -0.00015057978h, 0.1575829h, 0.25034854h, 0.054726984h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(-0.03807849h, -0.0440673h, 0.038429137h, -0.029738983h, 0.035449427h, -0.44138825h, -0.16462126h, -0.015045709h, 0.010627751h, -0.12178318h, -0.07076098h, -0.059846148h, 0.0009871369h, -0.07265447h, -0.01998304h, -0.018729536h), result);

                tex2_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(3, "Reconstruction Conv-4x3x3x4, Depth-to-Space")]
[bgfx::PASS_IO("INPUT, tex2", "OUTPUT")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass3(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;

    const uint2 outputSize = GetOutputSize();
    if (gxy.x >= outputSize.x || gxy.y >= outputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();
    float2 outputPt = GetOutputPt();

    float2 pos = ((gxy >> 1) + 0.5f) * inputPt;

    float2 tpos = pos - 0.5f * inputPt;
    const half4 sr = half4(tex2.GatherRed(sam, tpos));
    const half4 sg = half4(tex2.GatherGreen(sam, tpos));
    const half4 sb = half4(tex2.GatherBlue(sam, tpos));
    const half4 sa = half4(tex2.GatherAlpha(sam, tpos));

    half4 a = half4(sr.w, sg.w, sb.w, sa.w);
    half4 b = half4(sr.x, sg.x, sb.x, sa.x);
    half4 c = half4(tex2.SampleLevel(sam, pos + float2(-inputPt.x, inputPt.y), 0));
    half4 d = half4(sr.z, sg.z, sb.z, sa.z);
    half4 e = half4(sr.y, sg.y, sb.y, sa.y);
    half4 f = half4(tex2.SampleLevel(sam, pos + float2(0, inputPt.y), 0));
    half4 g = half4(tex2.SampleLevel(sam, pos + float2(inputPt.x, -inputPt.y), 0));
    half4 h = half4(tex2.SampleLevel(sam, pos + float2(inputPt.x, 0), 0));
    half4 i = half4(tex2.SampleLevel(sam, pos + float2(inputPt.x, inputPt.y), 0));

    half4 result = half4(-0.00016697648h, -0.00015957489h, 0.00017437353h, -0.00019393339h);
    result = MulAdd(max(a, half4(0)), half4x4(0.010651157h, 0.0018537974h, 0.0051580826h, 0.0020901994h, -0.41468114h, -0.08517094h, -0.04803197h, 0.008413933h, 0.014026587h, 0.012820705h, 0.01553548h, 0.01283508h, -0.040812977h, -0.015933262h, -0.01949977h, -0.011502392h), result);
    result = MulAdd(max(b, half4(0)), half4x4(0.2278103h, 0.06374709h, 0.062103115h, 0.02010158h, -0.01932597h, 0.01159983h, -0.35690293h, -0.062822886h, 0.29807624h, 0.036038283h, 0.028565003h, -0.025969796h, -0.24225195h, -0.06635989h, -0.06890857h, -0.010140013h), result);
    result = MulAdd(max(c, half4(0)), half4x4(-0.009164529h, -0.0036277112h, 0.19577485h, 0.05511193h, 0.025875263h, 0.020616682h, 0.02919653h, 0.030669902h, 0.00751339h, -0.00551052h, 0.2690018h, 0.035395138h, -0.013392302h, -0.03666098h, -0.23751089h, -0.11222924h), result);
    result = MulAdd(max(d, half4(0)), half4x4(0.017815048h, 0.011143683h, -0.002918766h, -0.0042153858h, -0.01929562h, -0.3405707h, 0.039267153h, 0.0041966257h, 0.0026771557h, 0.009982735h, 0.00087975257h, 0.003984122h, 0.0062404936h, -0.04230462h, 0.001981855h, -0.0145921325h), result);
    result = MulAdd(max(e, half4(0)), half4x4(-0.02615864h, 0.2872578h, 0.08103852h, 0.11812216h, -0.031988684h, -0.08532163h, -0.094653316h, -0.42660478h, 0.00077043264h, 0.284553h, -0.015517693h, 0.036667597h, 0.14234932h, -0.20201443h, -0.017204845h, -0.111502305h), result);
    result = MulAdd(max(f, half4(0)), half4x4(-0.11529456h, -0.09024149h, -0.2545015h, 0.08581955h, -0.020051582h, -0.031601675h, -0.031320736h, -0.051691536h, -0.019313173h, 0.028963564h, 0.017521648h, 0.3159018h, 0.179573h, 0.19400181h, 0.382411h, 0.076367974h), result);
    result = MulAdd(max(g, half4(0)), half4x4(-0.016741822h, -0.001993879h, -0.01517403h, -0.010949569h, 0.01859244h, 0.042316843h, 0.00025326485h, -0.007079785h, 0.001070783h, 0.000911405h, -0.0024269924h, -0.0014501393h, -0.01206317h, 0.007300575h, -0.0062582446h, -0.0016001783h), result);
    result = MulAdd(max(h, half4(0)), half4x4(-0.06300321h, -0.20786348h, 0.019603852h, 0.020122321h, 0.022107193h, 0.036766138h, 0.013046632h, 0.02677947h, -0.0006842017h, -0.044024136h, 0.0109439045h, 0.0040129004h, 0.009831765h, 0.15807834h, -0.05166107h, -0.014462446h), result);
    result = MulAdd(max(i, half4(0)), half4x4(-0.023205867h, -0.049788095h, -0.08251341h, -0.26488927h, 0.0029636251h, 0.021618038h, -0.0057556895h, 0.018444102h, 0.0064643323h, -0.027886944h, 0.010029941h, -0.041902024h, -0.021232832h, -0.0072857663h, 0.02056806h, 0.18491453h), result);

    pos -= 0.5f * outputPt;
    OUTPUT[gxy] = float4(result.x + half3(INPUT.SampleLevel(sam1, pos, 0).rgb), 1);

    ++gxy.x;
    pos.x += outputPt.x;
    OUTPUT[gxy] = float4(result.y + half3(INPUT.SampleLevel(sam1, pos, 0).rgb), 1);

    ++gxy.y;
    pos.y += outputPt.y;
    OUTPUT[gxy] = float4(result.w + half3(INPUT.SampleLevel(sam1, pos, 0).rgb), 1);

    --gxy.x;
    pos.x -= outputPt.x;
    OUTPUT[gxy] = float4(result.z + half3(INPUT.SampleLevel(sam1, pos, 0).rgb), 1);
}
