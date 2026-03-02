// Anime4K CNN x2 Upscaler (Small)
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

[bgfx::EFFECT("Anime4K Upscale S", 2)]
[bgfx::CATEGORY("Anime4K")]
[bgfx::DESCRIPTION("2x CNN upscaler for anime content. Small variant offers fastest performance with basic quality.")]
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
                half4 result = half4(-0.01050964h, -0.00939481h, 0.17684458h, 0.027366742h);
                result = MulAdd(src[i - 1][j - 1], half3x4(-0.0057322932h, 0.12928207h, -0.056848746h, 0.18680117h, -0.0306273h, 0.25602463h, 0.053723164h, 0.20419341h, 0.0018709862h, 0.022848232h, -0.04105527h, 0.101690340h), result);
                result = MulAdd(src[i - 1][j], half3x4(0.009471417h, -0.12957802h, 0.096014425h, 0.21836184h, 0.00021601951h, -0.22997683h, 0.23666254h, 0.41192335h, 0.021762101h, 0.0047863554h, 0.008233427h, 0.108514786h), result);
                result = MulAdd(src[i - 1][j + 1], half3x4(-0.01156376h, -0.18988979h, 0.04614705h, -0.044767227h, 0.01050636h, -0.26426336h, 0.23741047h, 0.0027636609h, -0.027718676h, -0.14202335h, -0.016650287h, -0.06637125h), result);
                result = MulAdd(src[i][j - 1], half3x4(0.057809234h, -0.11033858h, 0.056533534h, -0.06292466h, 0.13880666h, -0.18710336h, 0.2441031h, -0.25326246h, 0.0032683122h, -0.026437074h, 0.0023248852h, 7.640766e-05h), result);
                result = MulAdd(src[i][j], half3x4(-0.49110603h, 0.4429004h, -0.44015464h, -0.41174838h, -0.87738293h, 0.7808468h, -1.0929365h, -0.59699076h, -0.18409836h, 0.185138h, -0.11773224h, -0.17097276h), result);
                result = MulAdd(src[i][j + 1], half3x4(0.10580959h, -0.055947904h, -0.03431237h, -0.080236495h, 0.14862584h, -0.15393938h, -0.18872876h, -0.3170681h, 0.03559387h, -0.003990826h, 0.021298569h, 0.012844483h), result);
                result = MulAdd(src[i + 1][j - 1], half3x4(-0.040715586h, -0.25781113h, 0.08896714h, -0.1225879h, -0.15790503h, -0.54010904h, 0.29588607h, 0.10401059h, 0.003413123h, -0.108357325h, 0.0112870345h, -0.11888622h), result);
                result = MulAdd(src[i + 1][j], half3x4(0.0049315444h, 0.02376202h, -0.08224771h, 0.121118225h, -0.041512914h, -0.027994309h, -0.585988h, -0.069672115h, -0.017247835h, 0.0056576864h, 0.04319012h, 0.055003505h), result);
                result = MulAdd(src[i + 1][j + 1], half3x4(0.37521392h, 0.15916082h, 0.059708964h, 0.19046007h, 0.8120325h, 0.38343868h, 0.3436578h, 0.5287958h, 0.16570656h, 0.06957687h, 0.014022592h, 0.074799836h), result);

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
                half4 result = half4(0.012077211h, 0.013045883h, 0.0380778h, -0.02908858h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(-0.011029496h, 0.05866063h, -0.09460646h, -0.017664742h, -0.022488879h, 0.18384217h, -0.00397663h, -0.064733066h, 0.08466802h, 0.10667488h, 8.0212536e-05h, 0.0908869h, 0.13580276h, 0.00097438256h, 0.12176522h, -0.08218466h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(0.16062798h, -0.10190268h, 0.03280682h, 0.05621916h, -0.009684231h, -0.08464307h, 0.17058301h, -0.096469186h, 0.1967505h, -0.1450099h, 0.093607284h, -0.28240147h, -0.21377413h, 0.10079291h, -0.1741522h, 0.17330575h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(-0.060160473h, 0.06316997h, 0.0046929033h, -0.049405966h, 0.13851729h, 0.06830702h, -0.0586872h, -0.040827133h, 0.007052838h, -0.03576886h, -0.111261636h, 0.039155316h, -0.07380389h, -0.09369825h, 0.04471156h, 0.09678487h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(-0.36683616h, -0.035950605h, -0.24414362h, -0.009159744h, 0.19335322h, -0.099253505h, 0.075083904h, -0.00076695543h, 0.65291303h, -0.25599423h, 0.19827642h, 0.065899536h, -0.07423247h, -0.068967685h, 0.0050554527h, -0.060272824h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(-0.020688485h, -0.83178276h, 0.11104878h, 0.26454413h, 0.13655476h, 0.37675047h, -0.22219229h, -0.01751935h, 0.44552696h, 0.92510307h, 0.16063261h, -0.62011045h, 0.19366647h, -0.06996067h, -0.2504841h, 0.00803723h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(0.0051537007h, -0.057168536h, -0.16110587h, 0.25232598h, -0.04447099h, 0.11997351h, 0.14808103h, -0.34443566h, -0.26212573h, -0.21970181h, 0.2724405h, 0.21050811h, -0.07949061h, -0.064808235h, -0.21208277h, -0.0042361654h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(-0.0888952h, -0.20169449h, 0.19144905h, -0.016882861h, -0.013283103h, 0.07552998h, -0.24686803h, 0.012453213h, -0.065454446h, -0.016123284h, -0.47316182h, 0.070926026h, 0.09219782h, 0.13118166h, 0.074736096h, 0.0077910526h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(0.5832154h, 0.1138069h, -0.039765622h, 0.3182784h, -0.25497997h, 0.0013993139h, 0.39285088h, -0.48511526h, -0.39891505h, -0.19094779h, -0.082146175h, -0.20826934h, 0.020590555h, -0.0012490178h, -0.4398621h, 0.14377014h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(0.21917395h, 3.4314657e-05h, 0.25734863h, -0.3433305h, 0.015720673h, 0.2676127h, -0.06807297h, 0.15040149h, -0.23638041h, -0.0050233034h, -0.13666134h, 0.4542111h, -0.033572577h, -0.08450588h, -0.23341487h, 0.053490847h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(-0.17482175h, 0.057647135h, 0.33135444h, 0.0850751h, -0.1718849h, -0.0854123h, 0.036795795h, -0.13874969h, -0.10903869h, -0.19007301h, -0.06064334h, -0.03786032h, -0.036696054h, 0.07844446h, 0.012523185h, -0.01562906h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(-0.04411997h, -0.10331819h, 0.10050193h, 0.12406485h, 0.07431592h, 0.30109692h, -0.17511666h, -0.13263564h, -0.10192587h, 0.07821255h, -0.22415096h, 0.25552443h, 0.17881326h, -0.13914281h, 0.109979235h, -0.0016463579h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(-0.01911644h, -0.15412527h, 0.028903123h, 0.20831817h, 0.00375175h, 0.08110953h, 0.074919395h, -0.17581624h, -0.015677985h, 0.06504228h, 0.08817818h, -0.12518327h, -0.09537373h, 0.028905088h, -0.051288474h, 0.054334078h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(0.2852779h, -0.28924024h, 0.36805123h, 0.21079305h, -0.28336474h, 0.1679663h, -0.08641141h, -0.10699407h, -0.16090055h, 0.1287612h, -0.15910125h, 0.05734755h, 0.15883245h, 0.0053026294h, 0.080674745h, 0.0505137h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(0.17639062h, 0.3790122h, -0.19588692h, -0.020314282h, 0.26197383h, 0.09014768h, 0.19696823h, -0.41025418h, -0.08308115h, -0.33279485h, -0.22528782h, 0.06172439h, -0.1365661h, -0.13094363h, -0.005086559h, 0.089024484h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(0.05262993h, 0.0006296959h, 0.1657725h, -0.32591924h, 0.12126701h, 0.061543245h, -0.10526848h, 0.041583937h, 0.094976954h, 0.09416157h, -0.22019257h, -0.058390073h, -0.2073888h, 0.057273377h, 0.19558284h, 0.004208022h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(0.30005738h, 0.18478931h, -0.23342943h, 0.22455733h, -0.016488122h, 0.099634305h, 0.31620836h, -0.15731157h, 0.09595808h, 0.0013774688h, 0.48273298h, -0.07027936h, -0.18764344h, -0.26194447h, -0.11794225h, -0.012173601h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(0.117986746h, -0.13846518h, -0.019614812h, -0.3011192h, 0.5501164h, 0.3408611h, -0.40090847h, 0.15706886h, 0.13050972h, 0.051776595h, 0.20792943h, 0.23389706h, -0.22965533h, -0.053367328h, 0.3911586h, -0.032988597h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(0.054753624h, -0.008485731h, -0.2451672h, 0.17528129h, 0.13657846h, 0.010480436h, 0.07651423h, -0.43316832h, 0.12736236h, 0.13804524h, 0.12529011h, -0.30946237h, -0.14423579h, 0.08403089h, 0.24335162h, 0.057288036h), result);

                tex2_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(3, "Feature Processing Conv-4x3x3x8")]
[bgfx::PASS_IO("tex2", "tex1_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass3(uint3 tid: SV_DispatchThreadID)
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
            const half4 sr = half4(tex2.GatherRed(sam, tpos));
            const half4 sg = half4(tex2.GatherGreen(sam, tpos));
            const half4 sb = half4(tex2.GatherBlue(sam, tpos));
            const half4 sa = half4(tex2.GatherAlpha(sam, tpos));

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
                half4 result = half4(0.018736731h, -0.0026039074h, 0.050130025h, -0.055364225h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(-0.036115196h, -0.06971895h, -0.07508942h, 0.016036168h, 0.12120111h, 0.24536026h, 0.044755507h, -0.20663576h, 0.029635755h, -0.15427187h, 0.027148994h, -0.20795093h, 0.10170582h, 0.077919215h, 0.66063017h, -0.4632968h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(-0.0052889925h, -0.019060908h, -0.08660142h, -0.022095207h, -0.08097976h, -0.015142803h, -0.18552722h, -0.078493506h, -0.16293915h, -0.20099808h, -0.08370822h, 0.3701389h, 0.09094984h, 0.2487225h, 0.24338846h, 0.044003833h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(-0.061406493h, -0.017232792h, -0.10917424h, 0.11203319h, 0.040699825h, -0.019294346h, 0.084953666h, -0.018133596h, 0.07209552h, 0.016069936h, 0.17805555h, -0.089537814h, 0.15809004h, 0.1027023h, 0.15044671h, -0.15530108h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(0.0948676h, -0.040305693h, -0.005591629h, -0.048048403h, -0.07547777h, 0.056606572h, 0.021390207h, 0.32600567h, -0.20805131h, -0.099587254h, 0.029613169h, 0.0092129605h, -0.29429698h, -0.09898621h, 0.44470885h, -0.89487344h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(-0.122259885h, 0.11445877h, 0.06666907h, 0.1869428h, -0.1553992h, -0.1658741h, 0.2988138h, -0.57746625h, -0.34609964h, 0.11169158h, -0.41877756h, 0.38075635h, 0.21293911h, 0.09640372h, -0.12754214h, -0.08026104h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(0.15128808h, 0.050087795h, 0.09219755h, -0.18080945h, 0.0044571217h, -0.046019405h, -0.1289922h, 0.20305426h, 0.19601224h, 0.04667917h, 0.17465587h, 0.027672665h, 0.18441725h, 0.06845396h, 0.11288585h, -0.23283863h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(-0.072962h, -0.06639447h, 0.049347494h, -0.1386401h, 0.10396071h, 0.08187777h, -0.04280746h, 0.07390891h, 0.06628344h, 0.037797406h, 0.021885803h, -0.013147403h, 0.22376558h, 0.36243078h, 0.12874891h, -0.0023783944h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(0.074945286h, 0.16045591h, -0.11798349h, 0.12910712h, 0.054760084h, -0.095626175h, -0.047832094h, 0.03493912h, 0.11817307h, 0.037452437h, -0.14301221h, -0.027356789h, -0.052390423h, 0.11373512h, 0.07686775h, 0.010008694h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(-0.023999173h, -0.091900624h, 0.02388157h, 0.03173873h, 0.0065633506h, -0.033716757h, -0.1198324h, 0.12057766h, 0.026465805h, -0.07517131h, -0.07760598h, 0.060463097h, 0.07345541h, 0.046037503h, 0.21101558h, -0.26785463h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(0.15544604h, -0.03902825h, 0.04630384h, -0.25173616h, -0.0691359h, 0.07476507h, 0.009071253h, 0.089964196h, -0.26539803h, -0.3958477h, -0.22155671h, 0.20735882h, -0.105860494h, -0.003996804h, -0.044815883h, 0.39544627h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(0.6169709h, 0.23717614h, -0.37884676h, -0.7484867h, 0.020169826h, -0.30718836h, 1.0965588h, -0.20711036h, -0.39149985h, -0.06843563h, -0.06522909h, 0.103805855h, 0.03265825h, -0.15137726h, 0.12837899h, -0.01294922h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(-0.23638196h, -0.4560866h, -0.11948684h, -0.1464144h, 0.10690008h, 0.007835961h, 0.11864342h, -0.13101323h, -0.16509797h, 0.075027354h, 0.08122998h, 0.13451207h, 0.0011890623h, 0.052157886h, 0.08372405h, -0.07085038h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(-0.21997726h, -0.16488647h, -0.0291317h, 0.17997476h, 0.1493211h, 0.027494298h, 0.0034613227h, -0.3207727h, 0.18699001h, 0.14728633h, -0.042895135h, -0.07612043h, 0.125076h, -0.14714554h, -0.03480009h, -0.22753975h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(-0.5342686h, -0.7426105h, -0.38294584h, 0.42549992h, 0.46053204h, 0.7867879h, 0.106234804h, -0.041163098h, 0.5198579h, -0.5219404h, 0.14809476h, -0.41802374h, 0.06810794h, -0.15122683h, -0.047409h, 0.13178343h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(-0.50428164h, 0.18220626h, 0.35510704h, -0.081787474h, 0.03155813h, 0.019284263h, 0.0032388573h, -0.20513348h, -0.05385551h, 0.17803182h, -0.26206362h, 0.2870375h, 0.008557827h, 0.08401449h, -0.027598893h, -0.010791235h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(0.16657415h, 0.067647465h, 0.093076974h, -0.14438486h, -0.10017002h, 0.0022367141h, 0.03250936h, -0.052794546h, -0.009178676h, -0.019673595h, -0.0016697067h, -0.15424626h, -0.112123474h, -0.11079971h, 0.011987111h, -0.11747758h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(-0.023021797h, -0.058703423h, -0.037978355h, -0.062433913h, -0.13130441h, 0.048656322h, 0.056839373h, 0.109036915h, -0.07823158h, 0.14785293h, 0.058555078h, -0.11679035h, -0.14002073h, 0.07395252h, 0.098268874h, -0.06710464h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(0.14906375h, 0.030001195h, -0.10338215h, 0.0662968h, -0.161953h, -0.13682815h, 0.09563142h, 0.009514228h, -0.009491218h, 0.06737101h, -0.1393389h, 0.15231515h, -0.073147796h, 0.00767062h, 0.028675212h, 0.014213088h), result);

                tex1_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(4, "Reconstruction Conv-4x3x3x8, Depth-to-Space")]
[bgfx::PASS_IO("INPUT, tex1", "OUTPUT")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass4(uint3 tid: SV_DispatchThreadID)
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

    half4 a = half4(tex1.SampleLevel(sam, pos - inputPt, 0));
    half4 b = half4(tex1.SampleLevel(sam, pos + float2(-inputPt.x, 0), 0));
    half4 c = half4(tex1.SampleLevel(sam, pos + float2(-inputPt.x, inputPt.y), 0));
    half4 d = half4(tex1.SampleLevel(sam, pos + float2(0, -inputPt.y), 0));
    half4 e = half4(tex1.SampleLevel(sam, pos, 0));
    half4 f = half4(tex1.SampleLevel(sam, pos + float2(0, inputPt.y), 0));
    half4 g = half4(tex1.SampleLevel(sam, pos + float2(inputPt.x, -inputPt.y), 0));
    half4 h = half4(tex1.SampleLevel(sam, pos + float2(inputPt.x, 0), 0));
    half4 i = half4(tex1.SampleLevel(sam, pos + float2(inputPt.x, inputPt.y), 0));

    half4 result = half4(-0.00346731h, -0.0046263863h, -0.004627155h, -0.0057769152h);
    result = MulAdd(max(a, half4(0)), half4x4(0.019100675h, -0.014241565h, 0.004667036h, -0.03865062h, 0.106731094h, 0.026099661h, 0.014594411h, -0.011881356h, 0.0040967264h, -0.004626336h, 0.006469508h, 0.010875305h, -0.033909045h, -0.085905954h, 0.07861378h, 0.019452631h), result);
    result = MulAdd(max(b, half4(0)), half4x4(0.20777655h, -0.060354974h, 0.0023840065h, -0.064121604h, -0.17397617h, 0.019293457h, -0.09707183h, 0.080641985h, 0.01025124h, -0.017382381h, 0.008661793h, -0.010995665h, 0.21943407h, -0.115574986h, 0.14471593h, -0.068836235h), result);
    result = MulAdd(max(c, half4(0)), half4x4(0.057942886h, -0.06311754h, 0.2253396h, -0.04159292h, -0.020731755h, 0.007877151h, 0.041525815h, 0.025278691h, 0.03041967h, -0.025137542h, 0.024364179h, -0.024543528h, 0.029438615h, -0.015506873h, 0.081686h, -0.07812221h), result);
    result = MulAdd(max(d, half4(0)), half4x4(0.054237515h, 0.0676094h, -0.0047708177h, 0.0043467237h, -0.10032304h, -0.020498628h, 0.04240586h, 0.07272254h, 0.0784221h, 0.017945962h, -0.022310399h, -0.013134622h, 0.015638694h, -0.10001543h, 0.1043031h, 0.05898838h), result);
    result = MulAdd(max(e, half4(0)), half4x4(-0.021652509h, 0.35796642h, 0.059497777h, 0.23948468h, 0.15454951h, -0.10017235h, -0.19072174h, -0.44812536h, -0.03974552h, 0.04529369h, 0.22207436h, 0.026222564h, -0.09705454h, 0.5623026h, -0.3354105h, -0.017278556h), result);
    result = MulAdd(max(f, half4(0)), half4x4(-0.053682446h, -0.03411237h, -0.09399936h, 0.15128824h, -0.07463h, -0.042020727h, 0.0031783928h, 0.13481957h, -0.07731454h, 0.044114403h, -0.23085599h, 0.060444202h, -0.15015422h, 0.0018040676h, -0.18684982h, 0.2812511h), result);
    result = MulAdd(max(g, half4(0)), half4x4(0.0029329916h, 0.001596018h, 0.0007512241h, 0.016544111h, -0.04876942h, -0.05272409h, 0.037884697h, 0.049948208h, 0.015518177h, 0.11368592h, -0.03815777h, -0.013149978h, -0.027638039h, 0.107719295h, -0.04115787h, 0.02745414h), result);
    result = MulAdd(max(h, half4(0)), half4x4(0.016691081h, 0.010204119h, 0.04078854h, 0.01613337h, 0.03325829h, 0.0114824055h, -0.017286912h, -0.07284126h, -0.110984206h, -0.21041764h, 0.0089543555h, 0.18986733h, 0.01537506h, -0.2059135h, 0.029074017h, 0.013117443h), result);
    result = MulAdd(max(i, half4(0)), half4x4(0.013965926h, 0.029871881h, 0.0034499036h, -0.011343668h, 0.022120327h, -0.0068748263h, 0.009324342h, -0.039081004h, 0.08032371h, 0.050809264h, 0.035050742h, -0.2032847h, 0.06305391h, -0.021958945h, 0.038569167h, -0.22465245h), result);
    result = MulAdd(max(-a, half4(0)), half4x4(0.046307724h, -0.012419472h, 0.007673863h, -0.042344846h, 0.011042414h, 0.016994251h, -0.018166406h, -0.016955731h, -0.13240299h, 0.01768431h, -0.027607648h, 0.0699927h, -0.02840628h, 0.004414203h, 0.0049618417h, 0.011084679h), result);
    result = MulAdd(max(-b, half4(0)), half4x4(-0.119954154h, -0.007455482h, -0.031108133h, -0.009946449h, 0.0077065965h, 0.01660345h, 0.032943666h, 0.016376585h, 0.10273124h, 0.1556573h, -0.24643841h, 0.107307844h, -0.068235755h, 0.0561896h, -0.0104672015h, 0.042693343h), result);
    result = MulAdd(max(-c, half4(0)), half4x4(-0.01634601h, 0.04195375h, -0.10401894h, 0.047641944h, -0.034602515h, -0.0034419263h, -0.010457858h, 0.015194475h, -0.03962551h, -0.030031368h, 0.16036317h, 0.019283568h, -0.05877721h, 0.016504882h, -0.15523468h, 0.018161612h), result);
    result = MulAdd(max(-d, half4(0)), half4x4(-0.08083991h, 0.0024665035h, -0.049373373h, 0.030371357h, 0.0113322195h, -0.014676956h, 0.011646689h, -0.01142667h, 0.124930486h, 0.06625774h, -0.045840867h, -0.009693036h, -0.012649251h, -0.07388084h, 0.008790075h, 0.0013844534h), result);
    result = MulAdd(max(-e, half4(0)), half4x4(-0.33941835h, -0.2763476h, -0.118311435h, -0.063535266h, 0.20936015h, 0.13731301h, 0.13443594h, 0.07464433h, 0.059650812h, -0.36973104h, 0.16444235h, -0.37082872h, 0.06432777h, -0.18283032h, -0.044489607h, -0.13895285h), result);
    result = MulAdd(max(-f, half4(0)), half4x4(0.13533665h, 0.08268915h, -0.03675727h, -0.14348659h, 0.0186255h, -0.05051692h, 0.056702953h, 0.0061717895h, 0.047663026h, -0.088188455h, 0.23254345h, -0.014015464h, 0.08400204h, -0.0073777726h, 0.2202068h, -0.12366078h), result);
    result = MulAdd(max(-g, half4(0)), half4x4(0.04361004h, 0.046543695h, 0.0064863074h, -0.03358146h, -0.022602187h, 0.018138997h, -0.011071864h, 0.010244091h, -0.019814799h, -0.17250171h, 0.040823266h, -0.040131986h, 0.010125854h, 0.020660749h, 0.0020435036h, -0.010819304h), result);
    result = MulAdd(max(-h, half4(0)), half4x4(-0.004810193h, -0.11286074h, 0.051985834h, 0.04788631h, -0.023950428h, 0.036145125h, -0.038203828h, 0.052401308h, 0.022986965h, 0.26420745h, -0.06076917h, -0.09252999h, 0.03164547h, 0.15652153h, -0.037934h, -0.0035418556h), result);
    result = MulAdd(max(-i, half4(0)), half4x4(0.03358366h, -0.005219482h, 0.007060882h, -0.06569114h, -0.02941682h, 0.00966056h, -0.0153679885h, 0.019905418h, -0.107232265h, -0.03405676h, -0.044340115h, 0.26892832h, -0.04723829h, -0.02589829h, 0.004563232h, 0.19318114h), result);

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
