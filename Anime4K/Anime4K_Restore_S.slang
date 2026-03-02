// Anime4K Restore CNN (Small)
// Based on Anime4K project by bloc97

import bgfx;

#ifdef BG_FP16
#pragma warning(disable: 3557)
#endif

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

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

[bgfx::EFFECT("Anime4K Restore S", 2)]
[bgfx::CATEGORY("Anime4K")]
[bgfx::DESCRIPTION("CNN-based image restoration filter for anime content. Small variant offers fastest performance with basic quality.")]
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
                half4 result = half4(-0.011108127h, -0.07481861h, 0.07640154h, 0.4964964h);
                result = MulAdd(src[i - 1][j - 1], half3x4(-0.19288683h, -0.21397883h, 0.111997396h, -0.04791413h, -0.26682988h, -0.06144587h, -0.03601853h, -0.16693151h, 0.038494494h, -0.16651472h, 0.147657h, -0.083003886h), result);
                result = MulAdd(src[i - 1][j], half3x4(-0.14286195h, 0.08746566h, -0.40107322h, 0.12390977h, -0.33392772h, -0.18703035h, -0.21326795h, 0.04780781h, -0.15155545h, -0.0010025925h, -0.1554875h, -0.10676251h), result);
                result = MulAdd(src[i - 1][j + 1], half3x4(0.28095165h, 0.022872915h, -0.21342312h, -0.29982176h, 0.025937587h, -0.055012174h, -0.33779636h, 0.0015666655h, 0.076416336h, 0.06656033h, -0.1557806h, 0.1078894h), result);
                result = MulAdd(src[i][j - 1], half3x4(-0.31584853h, 0.07527119h, 0.30713862h, -0.34014285h, -0.50103146h, -0.07217874h, 0.512807h, -0.09597398h, -0.32097813h, -0.051580857h, -0.022466356h, 0.01148551h), result);
                result = MulAdd(src[i][j], half3x4(-0.026032459h, -0.04193211h, 0.37703893h, -0.031916667h, -0.27421117h, 1.0906446h, -0.049654085h, -0.19814016h, 0.07819544h, 0.06003738h, 0.1405805h, -0.0064135445h), result);
                result = MulAdd(src[i][j + 1], half3x4(0.041450135h, 0.11319654h, -0.23237701h, 0.08443178h, 0.53344345h, 0.30857387h, -0.057264958h, -0.1575803h, 0.2325609h, -0.027797326h, -0.04544767h, -0.18720597h), result);
                result = MulAdd(src[i + 1][j - 1], half3x4(0.2531829h, -0.074966915h, -0.27800754h, -0.3146097h, 0.20126024h, -0.5380133h, -0.15082566h, -0.19021043h, 0.29951036h, 0.17123336h, -0.01681872h, -0.12574998h), result);
                result = MulAdd(src[i + 1][j], half3x4(0.25203633h, 0.19882993h, 0.14906439h, 0.13593598h, 0.40712556h, 0.084902965h, 0.42969635h, 0.2961132h, -0.057267334h, -0.030388135h, 8.8084314e-05h, 0.0210724h), result);
                result = MulAdd(src[i + 1][j + 1], half3x4(-0.13459359h, -0.12199573h, 0.12591946h, 0.24736497h, 0.2033463h, -0.09388599h, -0.094370656h, 0.1071285h, -0.18479438h, -0.066625565h, 0.08279283h, 0.20130983h), result);

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
                half4 result = half4(-0.16371979h, -0.024620198h, -0.035754893h, 0.04176776h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(-0.056432575h, 0.0028165397h, -0.026325442h, -0.14802271h, 0.16885762h, -0.062179096h, -0.2332292h, 0.17513658h, -0.08011296h, 0.02947316h, 0.014771492h, -0.17946689h, 0.026012989h, -0.09823925h, 0.036625937h, -0.06924322h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(-0.13571467h, 0.09831142h, 0.12911566h, 0.06305893h, -0.07188695h, -0.20161287h, 0.3858435h, -0.21069056h, -0.12294444h, -0.1404628h, -0.022659872h, 0.23008968h, 0.10969853h, 0.17640765h, 0.39796907h, 0.20413099h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(-0.0061665224h, 0.055102807h, -0.0059629944h, -0.021429887h, 0.061626043h, 0.16898955h, -0.21215646h, 0.16510476h, 0.2238265h, 0.19429931h, 0.09874656h, 0.06828208h, -0.122404456h, -0.00026717107h, -0.28203064h, -0.29979932h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(-0.22735378h, 0.14538136h, 0.11549746h, 0.194148h, -0.09841722h, -0.0661309h, 0.348576h, -0.017375294h, -0.044078812h, 0.1298332h, 0.04793373h, -0.30687734h, 0.08353025h, 0.083519086h, 0.10766399h, 0.31796935h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(0.048365135h, -0.17566709h, -0.33212858h, -0.052667376h, -0.26443407h, -0.010216014h, 0.1573303h, 0.05725314h, 0.08140953h, -0.09664591h, 0.076109104h, -0.026773714h, 0.07732627h, 0.10188082h, -0.28266954h, -0.16230233h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(0.29931107h, 0.117944h, -0.10414009h, 0.12795551h, 0.12576093h, 0.17082554h, -0.15803693h, 0.13430743h, -0.025801308h, -0.10797019h, 0.0721032h, 0.2825884h, -0.11025257h, 0.12798019h, 0.081827976h, -0.050441865h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(-0.11827391h, 0.08306765h, -0.3430314h, 0.07898041h, -0.023839617h, -0.019507334h, 0.23176382h, -0.40992323h, 0.09411734h, 0.38415068h, -0.25845516h, -0.29984522h, 0.1470966h, -0.0684779h, -0.07071314h, -0.026773235h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(0.19091596h, 0.082110435h, -0.5266589h, -0.1744098h, -0.015838385h, -0.046316292h, 0.023171103h, -0.03731331h, 0.2642396h, 0.31824252h, -0.041754793h, -0.09525519h, -0.14696182h, 0.052168854h, 0.039857205h, -0.027555354h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(0.15207373h, 0.09845733h, 0.0142631065h, 0.096375965h, 0.06089903h, 0.17902578h, -0.42391995h, 0.22475442h, 0.016356342h, -0.06277531h, -0.12173141h, -0.18635495h, -0.0013459618h, 0.15725887h, 0.019310836h, 0.20293565h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(-0.18395247h, 0.30672902h, 0.09034339h, 0.1821889h, -0.0419004h, -0.2169228h, -0.14052129h, 0.11006559h, 0.1709272h, 0.51062274h, 0.13758625h, -0.2242552h, -0.030382963h, 0.3357568h, -0.26491287h, 0.02501938h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(0.040511727h, 0.12523083h, -0.27318433h, 0.08388512h, 0.25354835h, 0.3404216h, -0.2632471h, -0.17784123h, 0.2732347h, 0.4468553h, 0.084667034h, -0.1856242h, 0.034099877h, -0.00954992h, -0.32751867h, -0.062207516h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(0.17564747h, 0.11645554h, -0.16362113h, 0.105654195h, -0.2762563h, -0.1413764h, 0.23264363h, -0.14000498h, 0.095402054h, 0.0715738h, -0.19346157h, -0.028285999h, 0.009799127h, 0.04059529h, 0.19688335h, 0.1282381h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(0.23575781h, -0.11446148h, -0.20504695h, 0.035568226h, 0.36890212h, -0.85968876h, -0.18545328h, 0.33796397h, -0.30916876h, -0.10445518h, -0.3046253h, 0.33271998h, -0.06263589h, -0.2160114h, -0.16383372h, -0.31173357h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(0.20469664h, 0.4039374h, -0.070057206h, 0.030353077h, 0.39843914h, -0.15490077h, -0.24476516h, 0.38238233h, -0.21809858h, 0.23496576h, -0.051794037h, 0.033664484h, -0.14411364h, -0.2515329h, 0.124655396h, -0.05818785h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(-0.09065731h, -0.16787091h, 0.013269188h, 0.23687351h, -0.41504318h, -0.048163068h, 0.31760025h, -0.33648986h, 0.29752317h, 0.2926866h, 0.14408836h, -0.33382463h, -0.15873958h, -0.121961035h, 0.11797893h, 0.09000567h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(0.13356976h, 0.013763947h, 0.012169505h, -0.109594524h, 0.03417223h, 0.7031121h, 0.65146804h, 0.5250268h, -0.50132495h, -0.419648h, 0.2940041h, 0.83051753h, -0.17595838h, 0.1633008h, -0.018587278h, 0.079596795h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(0.07570128h, -0.1581438h, 0.03904949h, 0.14890033h, -0.054611947h, 0.17469402h, -0.44252598h, 0.036181703h, -0.4981031h, -0.37507218h, -0.18466389h, 0.2645845h, 0.25189674h, -0.025896115h, 0.034307647h, -0.020462232h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(-0.11645865h, 0.02296537h, 0.040909223h, 0.015069485h, 0.062284566h, -0.22526766h, 0.09241534h, -0.32623053h, 0.18208642h, 0.3954284h, 0.2884468h, -0.25137675h, -0.037232924h, -0.10185309h, -0.17956531h, 0.018966453h), result);

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
                half4 result = half4(-0.0036821906h, -0.050239526h, -0.01355402h, 0.00048220603h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(0.01921286h, -0.26684764h, -0.12663573h, 0.31641877h, -0.25313398h, 0.12264074h, 0.58750325h, -0.14084283h, 0.5837018h, -0.042300556h, -0.20435576h, -0.009954825h, 0.060783498h, 0.05540401h, 0.2205112h, -0.06578902h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(-0.21930243h, -0.03774968h, 0.22615197h, 0.18338196h, 0.011201461h, -0.271034h, 0.00573116h, -0.12248194h, 0.47990513h, 0.2982416h, -0.1087603h, -0.050099242h, -0.07620939h, -0.07148229h, 0.03691984h, -0.16796488h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(-0.14962853h, -0.053769328h, 0.02387081h, 0.22002189h, 0.052237745h, -0.26160842h, -0.08603077h, 0.012542448h, 0.08119985h, 0.075785555h, -0.33437458h, -0.43373227h, -0.13206963h, -0.08759176h, -0.03288923h, -0.09799959h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(-0.1305593h, -0.5974288h, 0.06058367h, 0.08406488h, 0.013692483h, 0.06646377h, 0.16469325h, 0.08990975h, 0.42217395h, -0.11289523h, -0.06165009h, 0.48556912h, -0.15702641h, -0.19922857h, -0.0035429662h, -0.0022089656h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(-0.1964807h, 0.038099788h, 0.21587034h, 0.039734077h, -0.07063389h, 0.11604167h, -0.24558097h, -0.08900199h, -0.7684516h, -0.1037487h, -0.09380674h, 0.33144563h, -0.16653742h, 0.0028585843h, -0.33774406h, -0.0528696h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(-0.27298656h, -0.05665099h, 0.09661685h, 0.19780266h, 0.1025106h, -0.22055034h, -0.21218458h, -0.040628925h, 0.0095010325h, 0.13118382h, -0.42582452h, -0.22197723h, 0.21006055h, -0.06189587h, -0.15285942h, -0.09526762h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(-0.14494462h, -0.046788953h, 0.065877035h, 0.09911713h, 0.35096622h, 0.16682479h, 0.028363144h, 0.36037162h, 0.29413632h, 0.28212717h, -0.025364442h, -0.3406269h, 0.047262143h, -0.11892685h, -0.008032766h, 0.29743317h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(-0.15191558h, -0.36980554h, 0.14555687h, 0.0043930537h, -0.012661432h, 0.15737776h, -0.115250416h, 0.10324491h, 0.24491951h, -0.15575431h, -0.27802598h, 0.21959937h, 0.18063772h, 0.4455559h, -0.09693302h, 0.33382267h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(0.2717801h, 0.13452889h, 0.14105384h, 0.16324317h, -0.40111846h, 0.1154301h, -0.0076733204h, -0.09697362h, 0.44306824h, -0.02831414h, -0.2153124h, -0.12075326h, 0.060776163h, 0.30347148h, -0.0036976219h, -0.12070682h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(-0.39780128h, -0.29875937h, -0.12952097h, 0.080333896h, 0.07520163h, 0.021689568h, -0.23121156h, -0.038140096h, -0.1593877h, 0.017156163h, -0.06038025h, 0.009244022h, -0.13917233h, 0.30957314h, 0.243109h, -0.104947075h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(-0.07965157h, 0.06776501h, -0.13288979h, 0.005851189h, -0.08768168h, -0.03689969h, 0.12034646h, 0.22441491h, 0.14453568h, -0.17648841h, -0.3378289h, -0.018329712h, 0.11722939h, -0.34161824h, 0.08424494h, -0.01400687h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(0.08153887h, 0.07222914h, -0.14663404h, -0.038526025h, -0.07385973h, 0.18440577h, 0.35890242h, 0.17084727h, 0.26345527h, 0.15280858h, -0.007446105h, -0.024403179h, -0.30336383h, -0.22978698h, 0.11612946h, -0.23614909h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(-0.07447396h, 0.09023449h, -0.13798h, -0.086943336h, -0.30787337h, 0.15087669h, 0.14418626h, -0.03371195h, 0.048989657h, -0.13075387h, -0.13458036h, -0.059836224h, 0.06495196h, 0.269715h, 0.3674355h, 0.38956037h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(0.34981915h, -0.048779126h, 0.31717536h, 0.38080826h, -0.20149232h, -0.82969636h, -0.10167862h, 0.6382858h, 0.25976858h, 0.4370118h, -0.04724865h, -0.10014156h, 0.19380626h, -0.080370255h, 0.09578106h, -0.035166856h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(-0.026443917h, 0.4132611h, 0.01822534h, 0.12742202h, -0.26652107h, -0.2996705h, 0.30905882h, 0.07989903h, 0.38249823h, 0.21486135h, 0.025314959h, -0.14717339h, -0.13344015h, -0.32088286h, -0.2833883h, -0.30973712h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(0.021517841h, 0.006556378h, 0.2025686h, -0.12044382h, -0.38583103h, -0.0027515136h, -0.06556736h, -0.097090125h, 0.04676486h, -0.11954886h, -0.051612873h, 0.07831412h, -0.18823163h, -0.16542958h, 0.04245155h, 0.6437998h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(-0.39475346h, -0.2936861h, 0.26768062h, -0.28151843h, 0.21935691h, 0.2101108h, -0.15455097h, 0.19548604h, 0.09188909h, -0.020147726h, 0.103328265h, -0.12574542h, -0.34167948h, 0.07523185h, -0.17669058h, 0.62446547h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(-0.37661025h, -0.29630858h, 0.05451026h, 0.1611643h, 0.14079669h, -0.2170294h, -0.038716137h, 0.13514164h, -0.21235192h, -0.07860726h, -0.005749412h, 0.025625167h, -0.13297133h, 0.33012658h, -0.27434957h, -0.18416783h), result);

                tex1_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(4, "Reconstruction Conv-3x3x3x8")]
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
    float2 pos = (gxy + 0.5f) * inputPt;

    half4 a = half4(tex1.SampleLevel(sam, pos + float2(-inputPt.x, -inputPt.y), 0));
    half4 b = half4(tex1.SampleLevel(sam, pos + float2(-inputPt.x, 0), 0));
    half4 c = half4(tex1.SampleLevel(sam, pos + float2(-inputPt.x, inputPt.y), 0));
    half4 d = half4(tex1.SampleLevel(sam, pos + float2(0, -inputPt.y), 0));
    half4 e = half4(tex1.SampleLevel(sam, pos, 0));
    half4 f = half4(tex1.SampleLevel(sam, pos + float2(0, inputPt.y), 0));
    half4 g = half4(tex1.SampleLevel(sam, pos + float2(inputPt.x, -inputPt.y), 0));
    half4 h = half4(tex1.SampleLevel(sam, pos + float2(inputPt.x, 0), 0));
    half4 i = half4(tex1.SampleLevel(sam, pos + float2(inputPt.x, inputPt.y), 0));

    half3 result = half3(-0.0052927984h, -0.0060193934h, -0.0048643993h);
    result = MulAdd(max(a, half4(0)), half4x3(0.15873h, 0.17989138h, 0.14648493h, -0.017379675h, -0.017363746h, -0.019855022h, 0.009670625h, 0.0070157526h, 0.0075994316h, 0.025388412h, 0.027231036h, 0.024052646h), result);
    result = MulAdd(max(b, half4(0)), half4x3(0.048195973h, 0.041760173h, 0.037366055h, -0.115950756h, -0.12887983h, -0.12535639h, 0.032125086h, 0.03397254h, 0.032950625h, 0.01223746h, 0.020822672h, 0.0161561h), result);
    result = MulAdd(max(c, half4(0)), half4x3(0.0890567h, 0.094453335h, 0.09014035h, 0.016081346h, 0.017434116h, 0.020783134h, -0.011775135h, -0.010094134h, -0.018522855h, 0.072103254h, 0.07940666h, 0.065876864h), result);
    result = MulAdd(max(d, half4(0)), half4x3(-0.04841196h, -0.06963968h, -0.056574684h, 0.10912542h, 0.11813441h, 0.10643838h, -0.013013885h, -0.01562045h, -0.013802797h, 0.037505716h, 0.04352026h, 0.04645123h), result);
    result = MulAdd(max(e, half4(0)), half4x3(-0.3472869h, -0.36243078h, -0.33530185h, 0.23654196h, 0.2305048h, 0.22150646h, -0.045226905h, -0.041799217h, -0.042511635h, -0.10267792h, -0.1123385h, -0.10845448h), result);
    result = MulAdd(max(f, half4(0)), half4x3(0.011987401h, 0.012285043h, 0.007813165h, -0.15911353h, -0.17523928h, -0.1535267h, 0.15675929h, 0.16531634h, 0.15948962h, -0.09240023h, -0.09513292h, -0.084187366h), result);
    result = MulAdd(max(g, half4(0)), half4x3(0.069052905h, 0.07278333h, 0.0756627h, -0.012180326h, -0.018794727h, -0.031050753h, -0.044663202h, -0.04362803h, -0.038904265h, -0.008540197h, -0.011201734h, -0.01556625h), result);
    result = MulAdd(max(h, half4(0)), half4x3(-0.08261173h, -0.09042543h, -0.07589266h, 0.043515377h, 0.045066774h, 0.04037769h, -0.06262993h, -0.07469342h, -0.058593787h, 0.026696987h, 0.028740842h, 0.037405368h), result);
    result = MulAdd(max(i, half4(0)), half4x3(0.07975598h, 0.09597654h, 0.08997132h, -0.07844719h, -0.07880916h, -0.06835411h, 0.05668995h, 0.050163813h, 0.053357534h, -0.020040333h, -0.019867316h, -0.01907621h), result);
    result = MulAdd(max(-a, half4(0)), half4x3(-0.017078733h, -0.017393313h, -0.008266595h, -0.0033478448h, -0.0027439648h, -0.0042334674h, -0.06354017h, -0.062058125h, -0.04652064h, -0.010787706h, -0.0062706997h, -0.007573461h), result);
    result = MulAdd(max(-b, half4(0)), half4x3(-0.019895451h, -0.016341688h, -0.008712399h, 0.026231976h, 0.023955572h, 0.0216376h, -0.061950512h, -0.05481285h, -0.05261985h, -0.018804235h, -0.016235247h, -0.0131616965h), result);
    result = MulAdd(max(-c, half4(0)), half4x3(-0.055628926h, -0.063315354h, -0.057192408h, -0.0256364h, -0.028660972h, -0.02937357h, -0.017604912h, -0.020851422h, -0.016070362h, -0.0870202h, -0.0832279h, -0.07525406h), result);
    result = MulAdd(max(-d, half4(0)), half4x3(0.062738225h, 0.07106593h, 0.061644047h, -0.06068257h, -0.06983662h, -0.066070385h, 0.024919355h, 0.03227179h, 0.028569462h, -0.07866227h, -0.098967604h, -0.092128105h), result);
    result = MulAdd(max(-e, half4(0)), half4x3(0.040397774h, 0.047241107h, 0.03962998h, -0.09112752h, -0.10057507h, -0.09301817h, 0.10833967h, 0.101835825h, 0.10027467h, 0.27189335h, 0.27433604h, 0.26781923h), result);
    result = MulAdd(max(-f, half4(0)), half4x3(-0.044211388h, -0.042373534h, -0.03658007h, 0.113148406h, 0.12423258h, 0.107804194h, -0.17081551h, -0.18562958h, -0.17475435h, 0.09636739h, 0.10763415h, 0.093332425h), result);
    result = MulAdd(max(-g, half4(0)), half4x3(-0.03798545h, -0.047811143h, -0.050768293h, 0.018775463h, 0.026812987h, 0.03452908h, 0.0055677597h, 0.0039081173h, -0.0017878668h, -0.10728597h, -0.12618187h, -0.109045394h), result);
    result = MulAdd(max(-h, half4(0)), half4x3(0.06359783h, 0.064184755h, 0.04934199h, -0.009819327h, -0.006616115h, -0.007431496h, 0.025055679h, 0.024787048h, 0.017360551h, -0.047140837h, -0.061695747h, -0.06440822h), result);
    result = MulAdd(max(-i, half4(0)), half4x3(0.060199022h, 0.06482763h, 0.059514645h, 0.026998974h, 0.028776823h, 0.024897143h, 0.17968474h, 0.19337215h, 0.16760105h, 0.0075838566h, 0.010503482h, 0.011993149h), result);

    result += half3(INPUT.SampleLevel(sam, pos, 0).rgb);

    OUTPUT[gxy] = float4(result, 1);
}
